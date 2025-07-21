// lib/network/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For debugPrint

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> saveItinerary(Map<String, dynamic> itineraryData) async {
    try {
      await _firestore.collection('itineraries').add({
        'location': itineraryData['location'],
        'departDay': itineraryData['departDay'],
        'returnDay': itineraryData['returnDay'],
        'departTime': itineraryData['departTime'],
        'returnTime': itineraryData['returnTime'],
        'totalDays': itineraryData['totalDays'],
        'budget': itineraryData['budget'],
        'itinerary': itineraryData['itinerary'],
        'suggestions': itineraryData['suggestions'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Itinerary saved to Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to save itinerary to Firestore: $e');
      throw Exception('Failed to save itinerary: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSavedItineraries() async {
    try {
      final querySnapshot = await _firestore
          .collection('itineraries')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch itineraries from Firestore: $e');
      throw Exception('Failed to fetch itineraries: $e');
    }
  }
}