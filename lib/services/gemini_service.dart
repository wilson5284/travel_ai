// lib/network/gemini_service.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firestore_service.dart';
import '../constants/api_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  static final FirestoreService _firestoreService = FirestoreService();

  static Future<Map<String, dynamic>> generateItinerary(
      String location,
      String departDay,   // Departure date string (yyyy-MM-dd)
      String returnDay,   // Return date string (yyyy-MM-dd)
      String departTime,  // Departure time string (e.g., "9:00 AM")
      String returnTime,  // Return time string (e.g., "5:00 PM")
      int totalDays,      // Total number of days for the trip
      double budget,
      ) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: ApiConstants.geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: 0.9,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
      );

      // Create a more detailed prompt - explicitly ask for day-by-day, time-specific, RM currency
      final prompt = '''
      Generate a detailed travel itinerary in JSON format for the following trip:
      - Location: $location
      - Departure Date: $departDay
      - Return Date: $returnDay
      - Departure Time: $departTime
      - Return Time: $returnTime
      - Total Days: $totalDays days
      - Budget: RM$budget
      
      The itinerary should be structured by day. Each day should contain multiple activities, and each activity must include these details:
      - day (e.g., "Day 1", "Day 2", ... up to "Day $totalDays")
      - time (e.g., "Morning", "Afternoon", "Evening", or specific time like "9:00 AM")
      - place (with emoji)
      - activity (with emoji)
      - estimated_duration
      - estimated_cost (in RM, e.g., "RM50")
      
      Ensure the itinerary is realistic, specific, and adheres to the budget and time constraints.
      Also, provide 3-5 general suggestions as an array.
      
      Example JSON format for a multi-day itinerary:
      {
        "itinerary": [
          {
            "day": "Day 1",
            "time": "Morning",
            "place": "Petronas Twin Towers 🏙️",
            "activity": "Visit Skybridge and Observation Deck 📸",
            "estimated_duration": "2 hours",
            "estimated_cost": "RM80"
          },
          {
            "day": "Day 1",
            "time": "Afternoon",
            "place": "Batu Caves 🕉️",
            "activity": "Climb steps, explore caves, see monkeys 🐒",
            "estimated_duration": "3 hours",
            "estimated_cost": "Free (donation welcomed)"
          },
          {
            "day": "Day 2",
            "time": "Morning",
            "place": "Kuala Lumpur Bird Park 🐦",
            "activity": "Explore the walk-in aviary and interact with birds 🦜",
            "estimated_duration": "2.5 hours",
            "estimated_cost": "RM65"
          }
          // ... more items for Day 1, Day 2, etc.
        ],
        "suggestions": [
          "Check weather forecast before traveling",
          "Book popular attraction tickets in advance to save time",
          "Use ride-sharing apps like Grab for convenience in Malaysia",
          "Stay hydrated, especially in tropical climates",
          "Carry sunscreen and a hat for sun protection"
        ]
      }
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      final jsonPattern = RegExp(r'\{[\s\S]*\}');
      final match = jsonPattern.firstMatch(responseText);

      if (match == null) {
        return {'error': 'Failed to parse API response from Gemini. It did not return a valid JSON format. Raw response: $responseText'};
      }

      final itineraryData = json.decode(match.group(0)!);

      // Save to Firestore (ensure firestore_service.dart is also updated to match new fields)
      await _firestoreService.saveItinerary({
        'location': location,
        'departDay': departDay,
        'returnDay': returnDay,
        'departTime': departTime,
        'returnTime': returnTime,
        'totalDays': totalDays,
        'budget': budget,
        'itinerary': itineraryData['itinerary'],
        'suggestions': itineraryData['suggestions'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return itineraryData;
    } catch (e) {
      print('Error in generateItinerary: $e');
      return {'error': 'Failed to generate itinerary: $e'};
    }
  }
}