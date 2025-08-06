// lib/services/weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherService {
  // 🔑 ADD YOUR WEATHERAPI.COM API KEY HERE
  final String _apiKey = 'f3aa98d0acef45b183590756250408';

  Future<Map<String, dynamic>> getWeatherForecast(String location) async {
    // Check if API key is configured
    if (_apiKey == 'PUT_YOUR_WEATHERAPI_KEY_HERE' || _apiKey.isEmpty) {
      return {
        'error': 'Weather API key not configured. Please add your WeatherAPI.com API key.'
      };
    }

    try {
      // Clean location name
      final cleanLocation = location.trim();
      if (cleanLocation.isEmpty) {
        return {'error': 'Location cannot be empty'};
      }

      // Build URL using Uri.https for proper encoding
      final uri = Uri.https(
          'api.weatherapi.com',
          '/v1/forecast.json',
          {
            'key': _apiKey,
            'q': cleanLocation,
            'days': '10',
            'aqi': 'no',
            'alerts': 'no'
          }
      );

      print('🌤️ Weather API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TravelApp/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      print('🌤️ Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Validate response has forecast data
        if (data.containsKey('forecast') &&
            data['forecast'] != null &&
            data['forecast']['forecastday'] != null) {
          print('✅ Weather data loaded for $location');
          return data;
        } else {
          return {'error': 'Invalid weather data structure'};
        }
      } else {
        // Handle API errors
        String errorMsg = 'Weather API error (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          errorMsg = errorData['error']?['message'] ?? errorMsg;
        } catch (e) {
          // Use default error message
        }

        return {'error': errorMsg};
      }
    } catch (e) {
      print('❌ Weather error: $e');
      return {'error': 'Failed to load weather: ${e.toString()}'};
    }
  }

  // Simple check for bad weather (used during itinerary generation)
  bool hasBadWeather(Map<String, dynamic> weatherData) {
    try {
      if (weatherData.containsKey('forecast') &&
          weatherData['forecast']['forecastday'] != null) {

        final List<dynamic> forecastDays = weatherData['forecast']['forecastday'];

        for (var day in forecastDays) {
          final condition = day['day']?['condition']?['text']?.toString().toLowerCase() ?? '';
          if (condition.contains('rain') || condition.contains('storm')) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get weather description for date range (used during itinerary generation)
  String getWeatherDescriptionForDateRange(Map<String, dynamic> weatherData, DateTime startDate, DateTime endDate) {
    try {
      if (weatherData.containsKey('forecast') &&
          weatherData['forecast']['forecastday'] != null) {

        final List<dynamic> forecastDays = weatherData['forecast']['forecastday'];
        final DateFormat apiDateFormat = DateFormat('yyyy-MM-dd');

        final List<String> conditions = [];

        for (var day in forecastDays) {
          if (day['date'] != null) {
            try {
              final DateTime forecastDate = apiDateFormat.parse(day['date']);

              if (forecastDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  forecastDate.isBefore(endDate.add(const Duration(days: 1)))) {

                final condition = day['day']?['condition']?['text'];
                if (condition != null) {
                  conditions.add(condition);
                }
              }
            } catch (e) {
              continue;
            }
          }
        }

        if (conditions.isNotEmpty) {
          return conditions.first; // Return most common or first condition
        }
      }

      return "Weather data unavailable";
    } catch (e) {
      return "Unable to process weather data";
    }
  }
}