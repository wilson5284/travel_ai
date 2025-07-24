// lib/network/weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // <--- ADD THIS IMPORT
import '../constants/api_constants.dart'; // Import your API constants

class WeatherService {
  final String _apiKey = ApiConstants.openWeatherApiKey;
  final String _baseUrl = "http://api.openweathermap.org/data/2.5/forecast"; // 5-day / 3-hour forecast

  // Fetches weather forecast for a given city
  Future<Map<String, dynamic>> getWeatherForecast(String city) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?q=$city&appid=$_apiKey&units=metric'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Handle API errors (e.g., city not found, invalid API key)
        final errorBody = json.decode(response.body);
        print("Weather API Error: ${response.statusCode} - ${errorBody['message']}");
        return {'error': 'Failed to load weather data: ${errorBody['message'] ?? 'Unknown error'}'};
      }
    } catch (e) {
      print("Network or parsing error in WeatherService: $e");
      return {'error': 'Network or data parsing error: $e'};
    }
  }

  // Checks for potentially "bad" weather conditions
  // This is a simplified check. You might want to define "bad weather" more strictly.
  bool hasBadWeather(Map<String, dynamic> weatherData) {
    if (weatherData.containsKey('error')) {
      return false; // Cannot determine if there's an error
    }

    final List<dynamic> forecasts = weatherData['list'];
    for (var forecast in forecasts) {
      final int weatherId = forecast['weather'][0]['id'];
      // OpenWeatherMap weather condition codes:
      // 2xx: Thunderstorm
      // 3xx: Drizzle
      // 5xx: Rain
      // 6xx: Snow
      // 7xx: Atmosphere (Mist, Smoke, Haze, Dust, Fog, Sand, Ash, Squall, Tornado) - some might be "bad"
      // 80x: Clouds (803, 804 might indicate heavy overcast)

      if (weatherId >= 200 && weatherId < 700) { // Thunderstorm, Drizzle, Rain, Snow
        return true;
      }
      if (weatherId == 701 || weatherId == 741) { // Mist or Fog
        return true;
      }
      if (weatherId == 803 || weatherId == 804) { // Broken clouds or Overcast clouds (can be a reminder)
        // return true; // You can uncomment this if heavy clouds are considered "bad"
      }
    }
    return false;
  }

  // Gets the weather description for a specific date (approximate)
  // This is a simplified lookup for a date range, as OpenWeatherMap provides 3-hour forecasts.
  String getWeatherDescriptionForDateRange(Map<String, dynamic> weatherData, DateTime startDate, DateTime endDate) {
    if (weatherData.containsKey('error')) {
      return "Weather info unavailable.";
    }

    final List<dynamic> forecasts = weatherData['list'];
    final List<String> conditions = [];
    final DateFormat formatter = DateFormat('yyyy-MM-dd'); // Correct usage with import

    for (var forecast in forecasts) {
      final DateTime forecastTime = DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000, isUtc: true).toLocal();
      // Check if forecast falls within the trip dates
      if (forecastTime.isAfter(startDate.subtract(Duration(days: 1))) && forecastTime.isBefore(endDate.add(Duration(days: 1)))) {
        final String main = forecast['weather'][0]['main'];
        final String description = forecast['weather'][0]['description'];
        conditions.add("$main ($description)");
      }
    }
    if (conditions.isEmpty) {
      return "No weather data for selected dates.";
    }
    // Remove duplicates and combine
    final uniqueConditions = conditions.toSet().join(', ');
    return "Expected weather: $uniqueConditions";
  }
}