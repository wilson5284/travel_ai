// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // 🔑 REPLACE WITH YOUR ACTUAL GEMINI API KEY
  static const String _apiKey = 'AIzaSyDMnNqMml28kCpFm8dJesw9VrUVFmbQUMA';

  // Test if API key is valid
  static Future<bool> testApiKey() async {
    if (_apiKey == 'PUT_YOUR_GEMINI_API_KEY_HERE' || _apiKey.isEmpty) {
      print('❌ API key not configured');
      return false;
    }

    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey';
      print('🧪 Testing API key with: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('🧪 API test response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ API key is valid');
        return true;
      } else if (response.statusCode == 403) {
        print('❌ API key invalid or no permission (403)');
        return false;
      } else {
        print('❌ API test failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ API test error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> generateItinerary(
      String location,
      String departDay,
      String returnDay,
      String departTime,
      String returnTime,
      int daysBetween,
      double budget,
      String interests,
      ) async {

    print('🚀 Starting itinerary generation for $location');

    // Check if API key is configured
    if (_apiKey == 'PUT_YOUR_GEMINI_API_KEY_HERE' || _apiKey.isEmpty) {
      print('❌ API key not configured');
      return {
        'error': 'Gemini API key not configured. Please add your API key to gemini_service.dart'
      };
    }

    // Test API key first
    final isValidKey = await testApiKey();
    if (!isValidKey) {
      print('❌ API key test failed, using fallback');
      return _createSimpleItinerary(location, departDay, daysBetween, budget);
    }

    final prompt = """
Create a travel itinerary JSON for $location.
Dates: $departDay to $returnDay ($daysBetween days)
Budget: RM$budget
Interests: $interests

Return ONLY this JSON format:
{
  "itinerary": [
    {
      "day": "Day 1",
      "date": "$departDay", 
      "time": "9:00 AM",
      "place": "Place Name",
      "activity": "Activity Description",
      "estimated_duration": "2 hours",
      "estimated_cost": "50"
    }
  ],
  "suggestions": ["Tip 1", "Tip 2", "Tip 3"]
}
""";

    try {
      // Simple URL construction to avoid URI issues
      final baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';
      final url = '$baseUrl?key=$_apiKey';

      print('🌐 API URL: $url');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.5,
          'maxOutputTokens': 4096,
        }
      };

      print('📤 Sending request to Gemini...');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TravelApp/1.0',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          print('📥 Response structure: ${responseData.keys}');

          if (responseData['candidates'] != null &&
              responseData['candidates'].isNotEmpty &&
              responseData['candidates'][0]['content'] != null &&
              responseData['candidates'][0]['content']['parts'] != null &&
              responseData['candidates'][0]['content']['parts'].isNotEmpty) {

            final generatedText = responseData['candidates'][0]['content']['parts'][0]['text'];
            print('🤖 Generated text length: ${generatedText.length}');
            print('🤖 First 200 chars: ${generatedText.substring(0, generatedText.length > 200 ? 200 : generatedText.length)}');

            // Parse JSON from response
            final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);

            if (jsonMatch != null) {
              final jsonString = jsonMatch.group(0)!;
              print('📋 Extracted JSON: ${jsonString.substring(0, jsonString.length > 300 ? 300 : jsonString.length)}...');

              try {
                final itineraryData = json.decode(jsonString);

                if (itineraryData.containsKey('itinerary') &&
                    itineraryData.containsKey('suggestions')) {
                  print('✅ Valid itinerary generated');
                  return itineraryData;
                } else {
                  print('❌ Invalid JSON structure');
                  return _createSimpleItinerary(location, departDay, daysBetween, budget);
                }
              } catch (jsonError) {
                print('❌ JSON parse error: $jsonError');
                return _createSimpleItinerary(location, departDay, daysBetween, budget);
              }
            } else {
              print('❌ No JSON found in response');
              return _createSimpleItinerary(location, departDay, daysBetween, budget);
            }
          } else {
            print('❌ Invalid response structure');
            return _createSimpleItinerary(location, departDay, daysBetween, budget);
          }
        } catch (e) {
          print('❌ Response parsing error: $e');
          return _createSimpleItinerary(location, departDay, daysBetween, budget);
        }
      } else {
        // Handle specific error codes
        print('❌ HTTP Error ${response.statusCode}');
        print('❌ Response body: ${response.body}');

        String errorMessage;
        switch (response.statusCode) {
          case 400:
            errorMessage = 'Bad request - check your request format';
            break;
          case 401:
            errorMessage = 'Unauthorized - invalid API key';
            break;
          case 403:
            errorMessage = 'Forbidden - API key lacks permission or quota exceeded';
            break;
          case 404:
            errorMessage = 'Model not found - check model name';
            break;
          case 429:
            errorMessage = 'Too many requests - rate limit exceeded';
            break;
          case 500:
            errorMessage = 'Server error - try again later';
            break;
          default:
            errorMessage = 'Unknown error (${response.statusCode})';
        }

        print('❌ Error: $errorMessage');
        return _createSimpleItinerary(location, departDay, daysBetween, budget);
      }
    } catch (e) {
      print('❌ Network/General error: $e');
      return _createSimpleItinerary(location, departDay, daysBetween, budget);
    }
  }

  // Create a simple fallback itinerary
  static Map<String, dynamic> _createSimpleItinerary(String location, String departDay, int daysBetween, double budget) {
    print('📋 Creating fallback itinerary for $location');

    final List<Map<String, dynamic>> itinerary = [];
    final costPerDay = budget / daysBetween;

    for (int i = 0; i < daysBetween; i++) {
      try {
        final date = DateTime.parse(departDay).add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];

        // Morning activity
        itinerary.add({
          'day': 'Day ${i + 1}',
          'date': dateStr,
          'time': '9:00 AM',
          'place': 'Main Attractions, $location',
          'activity': 'Explore city highlights and landmarks',
          'estimated_duration': '3 hours',
          'estimated_cost': '${(costPerDay * 0.4).toStringAsFixed(0)}'
        });

        // Afternoon activity
        itinerary.add({
          'day': 'Day ${i + 1}',
          'date': dateStr,
          'time': '1:00 PM',
          'place': 'Local Restaurant, $location',
          'activity': 'Lunch with local cuisine',
          'estimated_duration': '1.5 hours',
          'estimated_cost': '${(costPerDay * 0.3).toStringAsFixed(0)}'
        });

        // Evening activity
        itinerary.add({
          'day': 'Day ${i + 1}',
          'date': dateStr,
          'time': '4:00 PM',
          'place': 'Cultural Site, $location',
          'activity': 'Visit museums or cultural attractions',
          'estimated_duration': '2 hours',
          'estimated_cost': '${(costPerDay * 0.3).toStringAsFixed(0)}'
        });
      } catch (e) {
        print('❌ Error creating day ${i + 1}: $e');
        continue;
      }
    }

    return {
      'itinerary': itinerary,
      'suggestions': [
        'Download offline maps before traveling',
        'Learn basic local phrases for better communication',
        'Keep emergency contacts and documents handy',
        'Respect local customs and dress codes',
        'Stay hydrated and take breaks between activities'
      ]
    };
  }
}