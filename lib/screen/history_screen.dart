// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../network/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<Map<String, dynamic>>> _itinerariesFuture;

  @override
  void initState() {
    super.initState();
    _itinerariesFuture = _firestoreService.getSavedItineraries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Itineraries'),
        backgroundColor: Colors.black, // Match home screen aesthetic
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black, // Match home screen aesthetic
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itinerariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No saved itineraries found.', style: TextStyle(color: Colors.white)));
          } else {
            final itineraries = snapshot.data!;
            return ListView.builder(
              itemCount: itineraries.length,
              itemBuilder: (context, index) {
                final itineraryData = itineraries[index];
                final itineraryItems = itineraryData['itinerary'] as List<dynamic>? ?? [];
                final suggestions = itineraryData['suggestions'] as List<dynamic>? ?? [];

                // Display dates and times from Firestore
                final String departDay = itineraryData['departDay'] ?? 'N/A';
                final String returnDay = itineraryData['returnDay'] ?? 'N/A';
                final String departTime = itineraryData['departTime'] ?? 'N/A';
                final String returnTime = itineraryData['returnTime'] ?? 'N/A';
                final int totalDays = itineraryData['totalDays'] ?? 0;

                return Card(
                  margin: const EdgeInsets.all(16.0),
                  elevation: 4,
                  // Apply gradient background to the card
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
                          Text(
                            'Destination: ${itineraryData['location']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text('Duration: $totalDays days ($departDay $departTime - $returnDay $returnTime)', style: const TextStyle(color: Colors.white)),
                          Text('Budget: RM${(itineraryData['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
                          if (itineraryItems.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Itinerary Details:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            ...itineraryItems.map((item) => Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text(
                                '${item['day'] ?? 'Day N/A'}, ${item['time'] ?? 'Time N/A'}: ${item['place']} - ${item['activity']} (${item['estimated_duration']}, RM${item['estimated_cost']})',
                                style: const TextStyle(color: Colors.white),
                              ),
                            )).toList(),
                          ],
                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Suggestions:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            ...suggestions.map((s) => Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Text('- $s', style: const TextStyle(color: Colors.white)),
                            )).toList(),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Generated on: ${(itineraryData['createdAt'] as Timestamp?)?.toDate().toLocal().toString().split('.')[0] ?? 'N/A'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[200]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}