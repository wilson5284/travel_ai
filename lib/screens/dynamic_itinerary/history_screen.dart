// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_itinerary_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _itinerariesFuture = Future.value([]);

  // Color scheme consistent with ItineraryScreen.dart and ViewItineraryDetailScreen.dart
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  void _loadItineraries() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      setState(() {
        _itinerariesFuture = FirebaseFirestore.instance
            .collection('itineraries')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get()
            .then((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
          }).toList();
        }).catchError((error) {
          print("Error loading itineraries: $error");
          throw error;
        });
      });
    } else {
      setState(() {
        _itinerariesFuture = Future.value([]);
      });
    }
  }

  // NEW: Pull-to-refresh functionality
  Future<void> _refreshItineraries() async {
    _loadItineraries();
    // Wait a bit for the future to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // NEW: Show delete confirmation and handle deletion
  void _showDeleteDialog(Map<String, dynamic> itinerary) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Itinerary', style: TextStyle(color: _darkPurple)),
          content: Text(
            'Are you sure you want to delete the itinerary for ${itinerary['location']}?',
            style: TextStyle(color: _greyText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _greyText)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteItinerary(itinerary['id']);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // NEW: Delete itinerary function
  Future<void> _deleteItinerary(String itineraryId) async {
    try {
      await FirebaseFirestore.instance
          .collection('itineraries')
          .doc(itineraryId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Itinerary deleted successfully'),
          backgroundColor: _mediumPurple,
        ),
      );

      _loadItineraries(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete itinerary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Your Travel History',
          style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        // NEW: Add refresh button to app bar
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _darkPurple),
            onPressed: _refreshItineraries,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
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
        child: RefreshIndicator( // NEW: Added pull-to-refresh
          onRefresh: _refreshItineraries,
          color: _darkPurple,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _itinerariesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _darkPurple));
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 60, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading history',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshItineraries,
                          style: ElevatedButton.styleFrom(backgroundColor: _mediumPurple),
                          child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 80, color: _greyText.withOpacity(0.6)),
                      const SizedBox(height: 16),
                      Text(
                        'No saved itineraries yet.\nStart planning your next adventure!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _greyText, fontSize: 18),
                      ),
                    ],
                  ),
                );
              } else {
                final itineraries = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: itineraries.length,
                  itemBuilder: (context, index) {
                    final itineraryData = itineraries[index];

                    final String departDay = itineraryData['departDay'] ?? 'N/A';
                    final String returnDay = itineraryData['returnDay'] ?? 'N/A';
                    final String location = itineraryData['location'] ?? 'N/A';
                    final int totalDays = itineraryData['totalDays'] ?? 0;
                    final Timestamp? createdAt = itineraryData['createdAt'] as Timestamp?;

                    // Formatted creation date
                    final String formattedCreatedAt = createdAt != null
                        ? 'Saved: ${createdAt.toDate().toLocal().day}/${createdAt.toDate().toLocal().month}/${createdAt.toDate().toLocal().year}'
                        : 'N/A';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      shadowColor: _mediumPurple.withOpacity(0.2),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_offWhite, _lightPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () async {
                              final bool? deleted = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewItineraryDetailScreen(tripDetails: itineraryData),
                                ),
                              );
                              if (deleted == true) {
                                _loadItineraries();
                              }
                            },
                            onLongPress: () => _showDeleteDialog(itineraryData), // NEW: Long press to delete
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          location,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: _darkPurple,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.travel_explore, color: _mediumPurple, size: 30),
                                          // NEW: Add menu for delete option
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'delete') {
                                                _showDeleteDialog(itineraryData);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Delete'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            child: Icon(Icons.more_vert, color: _greyText),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Dates: $departDay - $returnDay ($totalDays days)',
                                    style: TextStyle(fontSize: 15, color: _greyText),
                                  ),
                                  Text(
                                    'Budget: RM${(itineraryData['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                                    style: TextStyle(fontSize: 15, color: _greyText),
                                  ),
                                  // NEW: Show interests if available
                                  if (itineraryData['interests'] != null && itineraryData['interests'].toString().isNotEmpty)
                                    Text(
                                      'Interests: ${itineraryData['interests']}',
                                      style: TextStyle(fontSize: 15, color: _greyText),
                                    ),
                                  const SizedBox(height: 12),
                                  // Display first few itinerary items for a quick glance
                                  if ((itineraryData['itinerary'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                                    Text(
                                      'Key Activities:',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: _greyText.withOpacity(0.8)),
                                    ),
                                    const SizedBox(height: 4),
                                    ...(itineraryData['itinerary'] as List<dynamic>)
                                        .take(2)
                                        .map((item) => Padding(
                                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                      child: Text(
                                        '• ${item['time'] ?? ''} - ${item['place'] ?? item['activity'] ?? 'Activity'}',
                                        style: TextStyle(fontSize: 14, color: _greyText),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )).toList(),
                                    if ((itineraryData['itinerary'] as List<dynamic>).length > 2)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                                        child: Text(
                                          'View details for more...',
                                          style: TextStyle(fontStyle: FontStyle.italic, color: _mediumPurple),
                                        ),
                                      ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // NEW: Add tap hint
                                      Text(
                                        'Tap to view • Long press to delete',
                                        style: TextStyle(fontSize: 11, color: _greyText.withOpacity(0.8), fontStyle: FontStyle.italic),
                                      ),
                                      Text(
                                        formattedCreatedAt,
                                        style: TextStyle(fontSize: 12, color: _greyText.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ),
    );
  }
}