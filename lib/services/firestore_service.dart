// lib/network/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For debugPrint

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // lib/network/firestore_service.dart (modify this function)
  Future<String> saveItinerary(Map<String, dynamic> itineraryData) async { // Change return type to String
    try {
      DocumentReference docRef = await _firestore.collection('itineraries').add({
        'userId': itineraryData['userId'],
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
      debugPrint('Itinerary saved to Firestore successfully with ID: ${docRef.id}');
      return docRef.id; // Return the ID
    } catch (e) {
      debugPrint('Failed to save itinerary to Firestore: $e');
      throw Exception('Failed to save itinerary: $e');
    }
  }

  Future<void> updateItinerary(String docId, Map<String, dynamic> updatedData) async {
    try {
      await _firestore.collection('itineraries').doc(docId).update(updatedData);
      debugPrint('Itinerary updated in Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to update itinerary in Firestore: $e');
      throw Exception('Failed to update itinerary: $e');
    }
  }

  Future<void> deleteItinerary(String docId) async {
    try {
      await _firestore.collection('itineraries').doc(docId).delete();
      debugPrint('Itinerary deleted from Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to delete itinerary from Firestore: $e');
      throw Exception('Failed to delete itinerary: $e');
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
          'id': doc.id, // Include the document ID
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch itineraries from Firestore: $e');
      throw Exception('Failed to fetch itineraries: $e');
    }
  }
}