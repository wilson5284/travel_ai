// lib/screens/view_itinerary_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../services/firestore_service.dart';
import '../../../utils/pdf_export.dart';
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

  // Color scheme consistent with ItineraryScreen.dart
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5); // Light violet
  final Color _gradientEnd = const Color(0xFFFFF5E6); // Light beige


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
          SnackBar(
            content: Text('Changes saved to history!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes to history: $e', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else if (widget.isNewTrip) {
      // If it's a new trip and we came from HomeScreen, save it for the first time
      // This case should ideally be handled when the trip is first generated in ItineraryScreen
      // and then its ID is passed here. For now, assuming it's already saved if it has no ID here.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New trip was already saved or cannot be re-saved without an ID.', style: TextStyle(color: _white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }


  Future<void> _shareItineraryAsPdf() async {
    if (_currentTripDetails.isEmpty || _currentItinerary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No itinerary data to share.', style: TextStyle(color: _white)),
          backgroundColor: _mediumPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
          SnackBar(
            content: Text('Failed to open PDF: ${result.message}', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Itinerary PDF generated and opened!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error generating or sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing itinerary: $e', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
        SnackBar(
          content: Text('Cannot delete: Trip ID not found.', style: TextStyle(color: _white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white, // Changed from black
          title: Text('Confirm Deletion', style: TextStyle(color: _darkPurple)), // Changed text color
          content: Text(
            'Are you sure you want to permanently delete this trip from your history?',
            style: TextStyle(color: _greyText), // Changed text color
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: _mediumPurple)), // Changed text color
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)), // Kept red for delete action
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
          SnackBar(
            content: Text('Trip deleted successfully!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop(true); // Signal to previous screen that trip was deleted
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete trip: $e', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
      backgroundColor: Colors.transparent, // Set to transparent to allow gradient in body
      appBar: AppBar(
        title: Text(
          'Itinerary for ${_currentTripDetails['location']}',
          style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white, // Match ItineraryScreen app bar
        foregroundColor: _darkPurple, // Icon color
        elevation: 0, // Remove shadow
        bottom: PreferredSize( // Add a thin bottom border for separation
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _darkPurple)) // Use purple for loading indicator
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip Overview',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dates: ${_currentTripDetails['departDay']} to ${_currentTripDetails['returnDay']}',
                style: TextStyle(fontSize: 16, color: _greyText),
              ),
              Text(
                'Budget: RM${(_currentTripDetails['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                style: TextStyle(fontSize: 16, color: _greyText),
              ),
              const SizedBox(height: 30), // Increased spacing

              // Action Buttons: Modify, Share, Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)], // Medium to Dark Purple
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15), // More rounded corners
                        boxShadow: [
                          BoxShadow(
                            color: _mediumPurple.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _navigateToModifyTripScreen,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0), // Consistent padding
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Modify',
                                  style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Adjusted spacing
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], // Green gradient for share
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _shareItineraryAsPdf,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.share, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Share PDF',
                                  style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent], // Red gradient for delete
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmAndDeleteTrip,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_forever, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Itinerary Details Display
              Text(
                'Detailed Plan',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here\'s your day-by-day breakdown of activities and estimated costs.',
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText,
                ),
              ),
              const SizedBox(height: 20),


              if (groupedItinerary.isNotEmpty)
                ...groupedItinerary.entries.map((entry) {
                  final dayKey = entry.key;
                  final dayItems = entry.value;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Consistent card rounding
                    ),
                    elevation: 5, // Consistent shadow
                    shadowColor: _mediumPurple.withOpacity(0.2), // Consistent shadow color
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_lightPurple, _offWhite], // Lighter gradient for daily cards
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Adjusted padding
                        title: Text(
                          dayKey,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: _darkPurple, // Dark purple for day title
                          ),
                        ),
                        iconColor: _darkPurple, // Dark purple for expand icon
                        children: dayItems.map<Widget>((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${item['time'] ?? 'N/A'}: ${item['place']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _darkPurple, // Dark purple for time and place
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "🎯 Activity: ${item['activity']}",
                                  style: TextStyle(fontSize: 14, color: _greyText),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "⏱️ Duration: ${item['estimated_duration']}",
                                  style: TextStyle(fontSize: 14, color: _greyText),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "💲 Cost: RM ${item['estimated_cost']}",
                                  style: TextStyle(fontSize: 14, color: _greyText),
                                ),
                                const Divider(color: Colors.grey, thickness: 0.2, height: 20), // Separator
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
                const SizedBox(height: 20),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: _mediumPurple.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_lightPurple, _offWhite], // Lighter gradient for suggestions card
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0), // Increased padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Travel Tips 📒",
                          style: TextStyle(
                            fontSize: 22, // Slightly larger font for header
                            fontWeight: FontWeight.bold,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._currentSuggestions.map((suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 8), // Padding between suggestions
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline, color: _mediumPurple, size: 20), // Lightbulb icon
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: TextStyle(fontSize: 15, color: _greyText, height: 1.4), // Adjusted line height
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24), // Add space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}