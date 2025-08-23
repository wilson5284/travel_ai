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

  // Enhanced itinerary generation with detailed preferences
  static Future<Map<String, dynamic>> generateEnhancedItinerary({
    required String location,
    required String departDay,
    required String returnDay,
    required String departTime,
    required String returnTime,
    required int daysBetween,
    required double budget,
    required String interests,
    String travelPace = 'moderate',
    String accommodationType = 'any',
    String transportPreference = 'any',
    List<String> mealPreferences = const [],
    Map<String, List<String>> selectedCategories = const {},
  }) async {

    print('🚀 Starting enhanced itinerary generation for $location');
    print('📋 User preferences: $interests');
    print('⚡ Travel pace: $travelPace');
    print('🏨 Accommodation: $accommodationType');
    print('🚗 Transport: $transportPreference');
    print('🍽️ Meal preferences: $mealPreferences');

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
      print('❌ API key test failed, using enhanced fallback');
      return _createEnhancedFallbackItinerary(
        location: location,
        departDay: departDay,
        daysBetween: daysBetween,
        budget: budget,
        interests: interests,
        travelPace: travelPace,
      );
    }

    // Build a comprehensive, highly detailed prompt
    final prompt = _buildEnhancedPrompt(
      location: location,
      departDay: departDay,
      returnDay: returnDay,
      departTime: departTime,
      returnTime: returnTime,
      daysBetween: daysBetween,
      budget: budget,
      interests: interests,
      travelPace: travelPace,
      accommodationType: accommodationType,
      transportPreference: transportPreference,
      mealPreferences: mealPreferences,
      selectedCategories: selectedCategories,
    );

    try {
      final baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';
      final url = '$baseUrl?key=$_apiKey';

      print('🌐 Sending enhanced request to Gemini...');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7, // Slightly higher for more creative responses
          'maxOutputTokens': 8192, // Increased for more detailed itineraries
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TravelApp/1.0',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 45)); // Increased timeout for longer responses

      print('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);

          if (responseData['candidates'] != null &&
              responseData['candidates'].isNotEmpty &&
              responseData['candidates'][0]['content'] != null &&
              responseData['candidates'][0]['content']['parts'] != null &&
              responseData['candidates'][0]['content']['parts'].isNotEmpty) {

            final generatedText = responseData['candidates'][0]['content']['parts'][0]['text'];
            print('🤖 Generated personalized itinerary');

            // Parse JSON from response
            final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);

            if (jsonMatch != null) {
              final jsonString = jsonMatch.group(0)!;

              try {
                final itineraryData = json.decode(jsonString);

                if (itineraryData.containsKey('itinerary') &&
                    itineraryData.containsKey('suggestions')) {
                  print('✅ Valid personalized itinerary generated');
                  return itineraryData;
                } else {
                  print('❌ Invalid JSON structure, using enhanced fallback');
                  return _createEnhancedFallbackItinerary(
                    location: location,
                    departDay: departDay,
                    daysBetween: daysBetween,
                    budget: budget,
                    interests: interests,
                    travelPace: travelPace,
                  );
                }
              } catch (jsonError) {
                print('❌ JSON parse error: $jsonError');
                return _createEnhancedFallbackItinerary(
                  location: location,
                  departDay: departDay,
                  daysBetween: daysBetween,
                  budget: budget,
                  interests: interests,
                  travelPace: travelPace,
                );
              }
            } else {
              print('❌ No JSON found in response');
              return _createEnhancedFallbackItinerary(
                location: location,
                departDay: departDay,
                daysBetween: daysBetween,
                budget: budget,
                interests: interests,
                travelPace: travelPace,
              );
            }
          } else {
            print('❌ Invalid response structure');
            return _createEnhancedFallbackItinerary(
              location: location,
              departDay: departDay,
              daysBetween: daysBetween,
              budget: budget,
              interests: interests,
              travelPace: travelPace,
            );
          }
        } catch (e) {
          print('❌ Response parsing error: $e');
          return _createEnhancedFallbackItinerary(
            location: location,
            departDay: departDay,
            daysBetween: daysBetween,
            budget: budget,
            interests: interests,
            travelPace: travelPace,
          );
        }
      } else {
        print('❌ HTTP Error ${response.statusCode}');
        return _createEnhancedFallbackItinerary(
          location: location,
          departDay: departDay,
          daysBetween: daysBetween,
          budget: budget,
          interests: interests,
          travelPace: travelPace,
        );
      }
    } catch (e) {
      print('❌ Network/General error: $e');
      return _createEnhancedFallbackItinerary(
        location: location,
        departDay: departDay,
        daysBetween: daysBetween,
        budget: budget,
        interests: interests,
        travelPace: travelPace,
      );
    }
  }

  // Build an enhanced, highly detailed prompt
  static String _buildEnhancedPrompt({
    required String location,
    required String departDay,
    required String returnDay,
    required String departTime,
    required String returnTime,
    required int daysBetween,
    required double budget,
    required String interests,
    required String travelPace,
    required String accommodationType,
    required String transportPreference,
    required List<String> mealPreferences,
    required Map<String, List<String>> selectedCategories,
  }) {

    // Parse interests for better understanding
    String detailedInterests = interests;
    if (selectedCategories.isNotEmpty) {
      List<String> categoryDetails = [];
      selectedCategories.forEach((category, items) {
        if (items.isNotEmpty) {
          categoryDetails.add('$category: ${items.join(", ")}');
        }
      });
      if (categoryDetails.isNotEmpty) {
        detailedInterests = '${categoryDetails.join(". ")}. Additional: $interests';
      }
    }

    // Determine activities per day based on pace
    int activitiesPerDay = travelPace == 'relaxed' ? 3 : travelPace == 'moderate' ? 4 : 5;

    // Calculate budget allocation
    double dailyBudget = budget / daysBetween;
    double accommodationBudget = dailyBudget * 0.35;
    double foodBudget = dailyBudget * 0.30;
    double activityBudget = dailyBudget * 0.25;
    double transportBudget = dailyBudget * 0.10;

    return """
You are an expert travel planner specializing in creating highly personalized itineraries for $location.

TRAVELER PROFILE:
- Travel Dates: $departDay to $returnDay ($daysBetween days)
- Departure Time: $departTime | Return Time: $returnTime
- Total Budget: RM$budget (Daily: RM${dailyBudget.toStringAsFixed(2)})
- Travel Pace: $travelPace (${travelPace == 'relaxed' ? '3-4 activities/day with rest time' : travelPace == 'moderate' ? '4-5 activities/day balanced' : '5-6 activities/day, maximize experiences'})
- Accommodation Preference: $accommodationType
- Transport Preference: $transportPreference
- Dietary Restrictions: ${mealPreferences.isNotEmpty ? mealPreferences.join(", ") : "None"}

SPECIFIC INTERESTS AND PREFERENCES (EXTREMELY IMPORTANT - MUST INCORPORATE):
$detailedInterests

CRITICAL INSTRUCTIONS:
1. EVERY activity MUST directly relate to the user's stated interests above
2. If user mentions specific interests (e.g., "Bangkok hip-hop fashion"), include ACTUAL places for those interests
3. Research and include REAL, SPECIFIC locations in $location that match their preferences
4. Avoid generic tourist attractions unless they align with stated interests
5. For food lovers, include specific restaurants/markets known for mentioned cuisines
6. For shopping interests, include actual shopping districts/stores that match their style
7. For cultural interests, include specific museums/galleries/temples that match
8. Include hidden gems and local favorites that tourists might not know

BUDGET BREAKDOWN PER DAY:
- Accommodation: RM${accommodationBudget.toStringAsFixed(0)}
- Food & Dining: RM${foodBudget.toStringAsFixed(0)}
- Activities: RM${activityBudget.toStringAsFixed(0)}
- Transport: RM${transportBudget.toStringAsFixed(0)}

Create a detailed JSON itinerary where:
- Each activity is SPECIFICALLY chosen based on the stated interests
- Include exact opening hours and days
- Provide specific transport instructions between locations
- Mention specific dishes to try at food locations
- Include insider tips for each location
- Add time for rest if pace is relaxed
- Consider weather and season for outdoor activities

For example, if someone says they like "Bangkok hip-hop fashion street":
- Include actual hip-hop fashion stores in Siam Square
- Recommend specific Thai streetwear brands
- Suggest the best times to visit for street fashion
- Include nearby hip-hop clubs or music venues

Return ONLY this JSON format with $activitiesPerDay activities per day:
{
  "itinerary": [
    {
      "day": "Day 1",
      "date": "$departDay",
      "time": "9:00 AM",
      "place": "[Specific place name and area in $location]",
      "activity": "[Detailed activity description that DIRECTLY relates to: $interests]",
      "estimated_duration": "[Duration]",
      "estimated_cost": "[Cost in RM]",
      "transport_to_next": "[Specific transport instructions]",
      "insider_tip": "[Local tip or best time to visit]",
      "relates_to_interest": "[Which specific interest this fulfills]"
    }
  ],
  "suggestions": [
    "[Specific tip about user's interests in $location]",
    "[Best areas in $location for their specific interests]",
    "[Money-saving tip related to their interests]",
    "[Safety or cultural tip for $location]",
    "[Backup options if weather is bad]",
    "[Apps or resources specific to their interests in $location]"
  ]
}

Remember: Every single activity MUST be chosen because it matches the user's stated interests: $interests
Do not include generic tourist activities unless specifically requested.""";
  }

  // Legacy simple generation method (keeping for backward compatibility)
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
    return generateEnhancedItinerary(
      location: location,
      departDay: departDay,
      returnDay: returnDay,
      departTime: departTime,
      returnTime: returnTime,
      daysBetween: daysBetween,
      budget: budget,
      interests: interests,
    );
  }

  // Create an enhanced fallback itinerary that considers preferences
  static Map<String, dynamic> _createEnhancedFallbackItinerary({
    required String location,
    required String departDay,
    required int daysBetween,
    required double budget,
    required String interests,
    required String travelPace,
  }) {
    print('📋 Creating enhanced fallback itinerary for $location');
    print('🎯 Attempting to match interests: $interests');

    final List<Map<String, dynamic>> itinerary = [];
    final costPerDay = budget / daysBetween;
    final activitiesPerDay = travelPace == 'relaxed' ? 3 : travelPace == 'moderate' ? 4 : 5;

    // Parse interests to create relevant activities
    final interestKeywords = interests.toLowerCase().split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList();

    // Activity templates based on common interests
    Map<String, List<Map<String, String>>> activityTemplates = {
      'food': [
        {'place': 'Famous Street Food Market', 'activity': 'Explore authentic local street food and try signature dishes'},
        {'place': 'Local Cooking Class', 'activity': 'Learn to cook traditional dishes with local chef'},
        {'place': 'Historic Food District', 'activity': 'Food tour through traditional restaurants and markets'},
      ],
      'shopping': [
        {'place': 'Main Shopping District', 'activity': 'Browse local fashion boutiques and designer stores'},
        {'place': 'Traditional Market', 'activity': 'Shop for unique souvenirs and local handicrafts'},
        {'place': 'Fashion Street', 'activity': 'Explore trendy fashion stores and streetwear shops'},
      ],
      'culture': [
        {'place': 'Cultural Heritage Site', 'activity': 'Guided tour of historical landmarks and monuments'},
        {'place': 'National Museum', 'activity': 'Explore art and cultural exhibitions'},
        {'place': 'Traditional Performance Theater', 'activity': 'Watch traditional cultural performances'},
      ],
      'nature': [
        {'place': 'Natural Park', 'activity': 'Hiking and nature photography in scenic landscapes'},
        {'place': 'Botanical Gardens', 'activity': 'Peaceful walk through themed gardens'},
        {'place': 'Scenic Viewpoint', 'activity': 'Sunrise or sunset viewing at panoramic location'},
      ],
      'fashion': [
        {'place': 'Fashion District', 'activity': 'Explore local designer boutiques and fashion trends'},
        {'place': 'Vintage Market', 'activity': 'Hunt for unique vintage fashion pieces'},
        {'place': 'Fashion Museum', 'activity': 'Learn about local fashion history and designers'},
      ],
      'nightlife': [
        {'place': 'Entertainment District', 'activity': 'Experience local nightlife and live music venues'},
        {'place': 'Night Market', 'activity': 'Evening shopping and street food experience'},
        {'place': 'Rooftop Bar District', 'activity': 'Enjoy city views from trendy rooftop venues'},
      ],
      'adventure': [
        {'place': 'Adventure Sports Center', 'activity': 'Try exciting outdoor activities and sports'},
        {'place': 'Water Sports Area', 'activity': 'Enjoy water-based adventure activities'},
        {'place': 'Mountain Trail', 'activity': 'Challenging hike with scenic rewards'},
      ],
      'art': [
        {'place': 'Contemporary Art Gallery', 'activity': 'Explore modern art exhibitions and installations'},
        {'place': 'Artist Quarter', 'activity': 'Visit artist studios and street art locations'},
        {'place': 'Art Workshop', 'activity': 'Hands-on art creation experience with local artists'},
      ],
    };

    // Default activities if no specific interests match
    List<Map<String, String>> defaultActivities = [
      {'place': 'City Center', 'activity': 'Explore main attractions and landmarks'},
      {'place': 'Local Restaurant', 'activity': 'Experience authentic local cuisine'},
      {'place': 'Cultural Site', 'activity': 'Learn about local history and traditions'},
      {'place': 'Shopping Area', 'activity': 'Browse local shops and markets'},
      {'place': 'Scenic Area', 'activity': 'Enjoy beautiful views and photo opportunities'},
    ];

    // Select relevant activities based on interests
    List<Map<String, String>> relevantActivities = [];

    for (String keyword in interestKeywords) {
      for (String templateKey in activityTemplates.keys) {
        if (keyword.contains(templateKey) || templateKey.contains(keyword)) {
          relevantActivities.addAll(activityTemplates[templateKey]!);
        }
      }
    }

    // Add specific interest-based activities
    if (interests.toLowerCase().contains('bangkok')) {
      relevantActivities.addAll([
        {'place': 'Chatuchak Weekend Market', 'activity': 'Explore Asia\'s largest weekend market'},
        {'place': 'Siam Square', 'activity': 'Shop for trendy fashion and street style'},
        {'place': 'Khao San Road', 'activity': 'Experience backpacker culture and street food'},
      ]);
    }

    if (interests.toLowerCase().contains('hip-hop') || interests.toLowerCase().contains('hiphop')) {
      relevantActivities.addAll([
        {'place': 'Underground Music Venue', 'activity': 'Experience local hip-hop scene and live performances'},
        {'place': 'Street Art District', 'activity': 'Explore graffiti and urban art culture'},
        {'place': 'Streetwear Shopping Area', 'activity': 'Shop for hip-hop fashion and streetwear brands'},
      ]);
    }

    // If no specific activities found, use defaults
    if (relevantActivities.isEmpty) {
      relevantActivities = defaultActivities;
    }

    // Generate itinerary for each day
    for (int i = 0; i < daysBetween; i++) {
      try {
        final date = DateTime.parse(departDay).add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];

        // Distribute activities throughout the day
        List<String> timeSlots = [];
        if (travelPace == 'relaxed') {
          timeSlots = ['9:00 AM', '1:00 PM', '5:00 PM'];
        } else if (travelPace == 'moderate') {
          timeSlots = ['9:00 AM', '11:30 AM', '2:00 PM', '5:00 PM'];
        } else {
          timeSlots = ['8:00 AM', '10:30 AM', '1:00 PM', '3:30 PM', '6:00 PM'];
        }

        for (int j = 0; j < activitiesPerDay && j < timeSlots.length; j++) {
          final activityIndex = (i * activitiesPerDay + j) % relevantActivities.length;
          final activity = relevantActivities[activityIndex];

          // Calculate cost based on activity type
          double activityCost = costPerDay / activitiesPerDay;
          if (j == 1 || j == 3) { // Meal times
            activityCost *= 0.8; // Food typically costs less
          }

          itinerary.add({
            'day': 'Day ${i + 1}',
            'date': dateStr,
            'time': timeSlots[j],
            'place': '${activity['place']}, $location',
            'activity': activity['activity']!,
            'estimated_duration': j == 1 || j == 3 ? '1.5 hours' : '2-3 hours',
            'estimated_cost': activityCost.toStringAsFixed(0),
            'transport_to_next': j < activitiesPerDay - 1 ? 'Taxi (15 min) or Public Transport (25 min)' : 'Return to accommodation',
            'insider_tip': 'Best to visit ${j < 2 ? 'in the morning to avoid crowds' : 'during golden hour for photos'}',
            'relates_to_interest': interestKeywords.isNotEmpty ? interestKeywords.first : 'general exploration'
          });
        }
      } catch (e) {
        print('❌ Error creating day ${i + 1}: $e');
        continue;
      }
    }

    // Generate personalized suggestions based on interests
    List<String> suggestions = [
      'Download offline maps and translation apps before exploring $location',
      'Best time for ${interestKeywords.isNotEmpty ? interestKeywords.first : "sightseeing"} is early morning or late afternoon',
    ];

    if (interests.toLowerCase().contains('food')) {
      suggestions.add('Try street food tours for authentic local flavors at budget prices');
      suggestions.add('Ask locals for their favorite food spots away from tourist areas');
    }

    if (interests.toLowerCase().contains('shopping') || interests.toLowerCase().contains('fashion')) {
      suggestions.add('Visit local markets early morning for best selection and prices');
      suggestions.add('Bargaining is expected in markets - start at 50% of asking price');
    }

    if (interests.toLowerCase().contains('culture') || interests.toLowerCase().contains('history')) {
      suggestions.add('Book guided tours for deeper cultural understanding and historical context');
      suggestions.add('Respect local customs and dress codes at religious sites');
    }

    if (interests.toLowerCase().contains('nature') || interests.toLowerCase().contains('outdoor')) {
      suggestions.add('Check weather forecasts and pack appropriate gear for outdoor activities');
      suggestions.add('Start outdoor activities early to avoid heat and crowds');
    }

    suggestions.addAll([
      'Keep emergency contacts and embassy information handy',
      'Consider travel insurance for activities and health coverage',
      'Stay hydrated and take breaks between activities, especially in hot weather'
    ]);

    return {
      'itinerary': itinerary,
      'suggestions': suggestions.take(6).toList(), // Limit to 6 most relevant suggestions
    };
  }
}