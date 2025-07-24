// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_itinerary_detail_screen.dart'; // Ensure this is imported

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<Map<String, dynamic>>> _itinerariesFuture;

  // Color scheme consistent with ItineraryScreen.dart and ViewItineraryDetailScreen.dart
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5); // Light violet from the background gradient
  final Color _lightBeige = const Color(0xFFFFF5E6); // Light beige from the background gradient
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5); // Light violet
  final Color _gradientEnd = const Color(0xFFFFF5E6); // Light beige

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  void _loadItineraries() {
    setState(() {
      _itinerariesFuture = _firestoreService.getSavedItineraries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set to transparent to allow gradient in body
      appBar: AppBar(
        title: Text(
          'Your Travel History', // More engaging title
          style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _white, // Consistent app bar background
        foregroundColor: _darkPurple, // Consistent icon color
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
            colors: [_gradientStart, _gradientEnd], // Use the consistent background gradient
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _itinerariesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _darkPurple)); // Use _darkPurple for loading
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading history: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 16),
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
                padding: const EdgeInsets.all(16.0), // Add padding around the list
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
                    margin: const EdgeInsets.symmetric(vertical: 8.0), // Spacing between cards
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Consistent card rounding
                    ),
                    elevation: 5, // Consistent shadow
                    shadowColor: _mediumPurple.withOpacity(0.2), // Consistent shadow color
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_offWhite, _lightPurple], // Lighter gradient for history cards
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Material( // Use Material for InkWell ripple effect
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
                              _loadItineraries(); // Reload history if a trip was deleted from detail screen
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20.0), // Increased padding inside card
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
                                          color: _darkPurple, // Dark purple for location
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.travel_explore, color: _mediumPurple, size: 30), // Travel icon
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
                                const SizedBox(height: 12),
                                // Display first few itinerary items for a quick glance
                                if ((itineraryData['itinerary'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                                  Text(
                                    'Key Activities:',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _greyText.withOpacity(0.8)),
                                  ),
                                  const SizedBox(height: 4),
                                  ...(itineraryData['itinerary'] as List<dynamic>)
                                      .take(2) // Show only first 2 activities
                                      .map((item) => Padding(
                                    padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                    child: Text(
                                      '• ${item['time'] ?? ''} - ${item['place']}',
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
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    formattedCreatedAt,
                                    style: TextStyle(fontSize: 12, color: _greyText.withOpacity(0.7)),
                                  ),
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
    );
  }
}