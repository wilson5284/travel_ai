// lib/screens/view_itinerary_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../services/firestore_service.dart';
import '../../utils/pdf_export.dart';
import 'modify_trip_screen.dart';

class ViewItineraryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tripDetails; // This will include the 'id' for Firestore operations
  final bool isNewTrip; // To differentiate if it's a newly generated trip or from history

  const ViewItineraryDetailScreen({
    super.key,
    required this.tripDetails,
    this.isNewTrip = false, // Default to false
  });

  @override
  State<ViewItineraryDetailScreen> createState() => _ViewItineraryDetailScreenState();
}

class _ViewItineraryDetailScreenState extends State<ViewItineraryDetailScreen> {
  late Map<String, dynamic> _currentTripDetails;
  late List<Map<String, dynamic>> _currentItinerary;
  late List<String> _currentSuggestions;
  bool _isLoading = false; // For PDF generation/deletion

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _currentTripDetails = Map<String, dynamic>.from(widget.tripDetails);
    _currentItinerary = List<Map<String, dynamic>>.from(_currentTripDetails['itinerary']);
    _currentSuggestions = List<String>.from(_currentTripDetails['suggestions']);
  }

  // Helper to group flat itinerary list by day
  Map<String, List<Map<String, dynamic>>> _groupItineraryByDay(List<Map<String, dynamic>> itinerary) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in itinerary) {
      final dayKey = item['day'] as String? ?? 'Unknown Day';
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      // Sort activities within each day by time, if 'time' is available
      final String timeStr = item['time']?.toString().toLowerCase() ?? 'z'; // 'z' for sorting at end
      final String sortKey = timeStr.contains('morning') ? 'a' :
      timeStr.contains('afternoon') ? 'b' :
      timeStr.contains('evening') ? 'c' :
      timeStr.substring(0,2) ; // For 9:00 AM etc.

      grouped[dayKey]!.add({...item, '_sortKey': sortKey}); // Add a temporary sort key
    }

    // Sort activities within each day
    grouped.forEach((key, value) {
      value.sort((a, b) => (a['_sortKey'] as String).compareTo(b['_sortKey'] as String));
    });

    // Sort day keys like "Day 1", "Day 2" numerically
    final sortedKeys = grouped.keys.toList();
    sortedKeys.sort((a, b) {
      final aNum = int.tryParse(a.replaceAll('Day ', '')) ?? 0;
      final bNum = int.tryParse(b.replaceAll('Day ', '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    final sortedGrouped = <String, List<Map<String, dynamic>>>{};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    return sortedGrouped;
  }

  void _deleteItineraryDayLocally(int dayIndex) {
    setState(() {
      _currentItinerary.removeWhere((item) {
        final itemDay = item['day'] as String?;
        return itemDay == 'Day ${dayIndex + 1}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted Day ${dayIndex + 1} from display. Remember to save changes to persist.')),
      );
      // If you want to update Firestore immediately after deleting a day locally:
      // _saveChangesToFirestore();
    });
  }

  Future<void> _navigateToModifyTripScreen() async {
    final Map<String, dynamic>? updatedTrip = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModifyTripScreen(initialTripDetails: _currentTripDetails),
      ),
    );

    if (updatedTrip != null) {
      setState(() {
        _currentItinerary = (updatedTrip['itinerary'] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _currentSuggestions = (updatedTrip['suggestions'] as List<dynamic>)
            .map((item) => item as String)
            .toList();
        _currentTripDetails = updatedTrip; // Update the stored trip details
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itinerary updated successfully!')),
      );

      // Save changes to Firestore immediately after modification
      await _saveChangesToFirestore();
    }
  }

  Future<void> _saveChangesToFirestore() async {
    if (_currentTripDetails.containsKey('id')) {
      try {
        await _firestoreService.updateItinerary(
          _currentTripDetails['id'],
          {
            'itinerary': _currentItinerary,
            'suggestions': _currentSuggestions,
            // You might want to update other fields like dates, budget if they are editable too
            // For now, modify_trip_screen only changes itinerary/suggestions
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved to history!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes to history: $e')),
        );
      }
    } else if (widget.isNewTrip) {
      // If it's a new trip and we came from HomeScreen, save it for the first time
      try {
        await _firestoreService.saveItinerary(_currentTripDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New trip saved to history!')),
        );
        // After saving, add the ID to _currentTripDetails so subsequent saves update it
        // This is a bit tricky as add() doesn't return ID immediately.
        // A better way is to make saveItinerary return the new doc ID.
        // For now, we'll assume it's saved and rely on re-fetching from history if needed later.
        // Or, in home_screen.dart, you could make the first save and then navigate here with the ID.
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save new trip to history: $e')),
        );
      }
    }
  }

  Future<void> _shareItineraryAsPdf() async {
    if (_currentTripDetails.isEmpty || _currentItinerary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No itinerary data to share.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pdfBytes = await PdfExport.generatePdf(
        _currentTripDetails['location'] as String,
        _currentTripDetails['departDay'] as String,
        _currentTripDetails['returnDay'] as String,
        _currentTripDetails['budget'] as double,
        _currentItinerary,
        _currentSuggestions,
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/itinerary_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open PDF: ${result.message}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Itinerary PDF generated and opened!')),
        );
      }
    } catch (e) {
      print('Error generating or sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing itinerary: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndDeleteTrip() async {
    final String? docId = _currentTripDetails['id'];
    if (docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Trip ID not found.')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to permanently delete this trip from your history?', style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _firestoreService.deleteItinerary(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully!')),
        );
        Navigator.of(context).pop(true); // Signal to previous screen that trip was deleted
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete trip: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedItinerary = _groupItineraryByDay(_currentItinerary);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Itinerary for ${_currentTripDetails['location']}',
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates: ${_currentTripDetails['departDay']} to ${_currentTripDetails['returnDay']}',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Text(
              'Budget: RM${(_currentTripDetails['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // Action Buttons: Modify, Share, Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _navigateToModifyTripScreen,
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text('Modify', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color.fromARGB(255, 0, 163, 102), Color.fromARGB(255, 0, 77, 108)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _shareItineraryAsPdf,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Share PDF', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.redAccent],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndDeleteTrip,
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      label: const Text('Delete', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Itinerary Details Display
            if (groupedItinerary.isNotEmpty)
              ...groupedItinerary.entries.map((entry) {
                final dayKey = entry.key;
                final dayItems = entry.value;

                final dayIndex = int.tryParse(dayKey.replaceAll('Day ', '')) != null
                    ? int.parse(dayKey.replaceAll('Day ', '')) - 1
                    : -1;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        dayKey,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      // Removed the individual delete day button here, as the main delete button removes the whole trip.
                      // If you need to delete a specific day, you'd integrate it with the _navigateToModifyTripScreen
                      // or re-add a _deleteItineraryDayLocally and a save button.
                      children: dayItems.map<Widget>((item) {
                        return ListTile(
                          title: Text(
                            "${item['place']} (${item['time'] ?? 'N/A'})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                "🎯 Activity : ${item['activity']}",
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "⏱️ Duration : ${item['estimated_duration']}",
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "💲 Cost : RM ${item['estimated_cost']}",
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),

            // Suggestions List
            if (_currentSuggestions.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tips 📒",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        ..._currentSuggestions.map((suggestion) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "💡 $suggestion",
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}