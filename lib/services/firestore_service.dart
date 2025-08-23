// lib/network/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For debugPrint
import 'package:firebase_auth/firebase_auth.dart'; // Added for user authentication

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Your existing method - unchanged
  Future<String> saveItinerary(Map<String, dynamic> itineraryData) async {
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
      return docRef.id;
    } catch (e) {
      debugPrint('Failed to save itinerary to Firestore: $e');
      throw Exception('Failed to save itinerary: $e');
    }
  }

  // Your existing method - unchanged
  Future<void> updateItinerary(String docId, Map<String, dynamic> updatedData) async {
    try {
      await _firestore.collection('itineraries').doc(docId).update(updatedData);
      debugPrint('Itinerary updated in Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to update itinerary in Firestore: $e');
      throw Exception('Failed to update itinerary: $e');
    }
  }

  // Your existing method - unchanged
  Future<void> deleteItinerary(String docId) async {
    try {
      await _firestore.collection('itineraries').doc(docId).delete();
      debugPrint('Itinerary deleted from Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to delete itinerary from Firestore: $e');
      throw Exception('Failed to delete itinerary: $e');
    }
  }

  // Your existing method - unchanged
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

  // NEW METHOD: Get saved itineraries for a specific user
  Future<List<Map<String, dynamic>>> getUserSavedItineraries(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('itineraries')
          .where('userId', isEqualTo: userId)
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
      debugPrint('Failed to fetch user itineraries from Firestore: $e');
      throw Exception('Failed to fetch user itineraries: $e');
    }
  }

  // NEW METHOD: Get current user's itineraries (convenience method)
  Future<List<Map<String, dynamic>>> getCurrentUserItineraries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      return getUserSavedItineraries(user.uid);
    } catch (e) {
      debugPrint('Failed to fetch current user itineraries: $e');
      throw Exception('Failed to fetch current user itineraries: $e');
    }
  }

  // NEW METHOD: Check if itinerary belongs to user (security helper)
  Future<bool> isItineraryOwnedByUser(String docId, String userId) async {
    try {
      final doc = await _firestore.collection('itineraries').doc(docId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['userId'] == userId;
    } catch (e) {
      debugPrint('Failed to check itinerary ownership: $e');
      return false;
    }
  }

  // NEW METHOD: Get itinerary by ID with user check
  Future<Map<String, dynamic>?> getItineraryById(String docId, {bool checkUser = true}) async {
    try {
      final doc = await _firestore.collection('itineraries').doc(docId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      if (checkUser) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || data['userId'] != user.uid) {
          throw Exception('Access denied: Itinerary does not belong to current user');
        }
      }

      return {
        'id': doc.id,
        ...data,
      };
    } catch (e) {
      debugPrint('Failed to get itinerary by ID: $e');
      throw Exception('Failed to get itinerary: $e');
    }
  }

  // NEW METHOD: Get user trip statistics
  Future<Map<String, int>> getUserTripStatistics(String userId) async {
    try {
      final trips = await getUserSavedItineraries(userId);
      final now = DateTime.now();

      int upcoming = 0;
      int active = 0;
      int completed = 0;
      int thisMonth = 0;

      for (final trip in trips) {
        final departDate = DateTime.parse(trip['departDay']);
        final returnDate = DateTime.parse(trip['returnDay']);

        final isUpcoming = departDate.isAfter(now);
        final isActive = now.isAfter(departDate) && now.isBefore(returnDate.add(const Duration(days: 1)));
        final isPast = returnDate.isBefore(now);

        if (isUpcoming) upcoming++;
        if (isActive) active++;
        if (isPast) completed++;

        if (departDate.year == now.year && departDate.month == now.month) {
          thisMonth++;
        }
      }

      return {
        'total': trips.length,
        'upcoming': upcoming,
        'active': active,
        'completed': completed,
        'thisMonth': thisMonth,
      };
    } catch (e) {
      debugPrint('Failed to get user trip statistics: $e');
      return {
        'total': 0,
        'upcoming': 0,
        'active': 0,
        'completed': 0,
        'thisMonth': 0,
      };
    }
  }

  // NEW METHOD: Delete user's itinerary with security check
  Future<void> deleteUserItinerary(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if itinerary belongs to user
      final isOwner = await isItineraryOwnedByUser(docId, user.uid);
      if (!isOwner) {
        throw Exception('Access denied: Cannot delete itinerary that does not belong to you');
      }

      await _firestore.collection('itineraries').doc(docId).delete();
      debugPrint('User itinerary deleted from Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to delete user itinerary from Firestore: $e');
      throw Exception('Failed to delete user itinerary: $e');
    }
  }

  // NEW METHOD: Update user's itinerary with security check
  Future<void> updateUserItinerary(String docId, Map<String, dynamic> updatedData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if itinerary belongs to user
      final isOwner = await isItineraryOwnedByUser(docId, user.uid);
      if (!isOwner) {
        throw Exception('Access denied: Cannot update itinerary that does not belong to you');
      }

      // Add last modified timestamp
      updatedData['lastModified'] = FieldValue.serverTimestamp();

      await _firestore.collection('itineraries').doc(docId).update(updatedData);
      debugPrint('User itinerary updated in Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to update user itinerary in Firestore: $e');
      throw Exception('Failed to update user itinerary: $e');
    }
  }
}