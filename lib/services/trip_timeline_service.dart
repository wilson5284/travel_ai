import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firestore_service.dart';
import 'weather_service.dart';

class TripTimelineService {
  static final TripTimelineService _instance = TripTimelineService._internal();
  factory TripTimelineService() => _instance;
  TripTimelineService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();

  // Get all trips with timeline status
  Future<List<Map<String, dynamic>>> getTripsWithStatus() async {
    try {
      final List<Map<String, dynamic>> trips = await _firestoreService.getSavedItineraries();
      final DateTime now = DateTime.now();

      return trips.map((trip) {
        final departDate = DateTime.parse(trip['departDay']);
        final returnDate = DateTime.parse(trip['returnDay']);
        final daysUntilTrip = departDate.difference(now).inDays;

        // Add status information
        trip['daysUntilTrip'] = daysUntilTrip;
        trip['isUpcoming'] = departDate.isAfter(now);
        trip['isActive'] = now.isAfter(departDate) && now.isBefore(returnDate.add(const Duration(days: 1)));
        trip['isPast'] = returnDate.isBefore(now);
        trip['status'] = _getTripStatus(daysUntilTrip, trip['isActive'], trip['isPast']);
        trip['urgency'] = _getTripUrgency(daysUntilTrip, trip['isActive']);

        return trip;
      }).toList();
    } catch (e) {
      print('Error getting trips with status: $e');
      return [];
    }
  }

  // Get trips that need attention (upcoming with alerts)
  Future<List<Map<String, dynamic>>> getTripsNeedingAttention() async {
    final trips = await getTripsWithStatus();
    final now = DateTime.now();

    return trips.where((trip) {
      final daysUntilTrip = trip['daysUntilTrip'] as int;
      return daysUntilTrip >= 0 && daysUntilTrip <= 14; // Next 2 weeks
    }).toList();
  }

  // Get weather alerts for upcoming trips
  Future<List<Map<String, dynamic>>> getWeatherAlerts() async {
    final upcomingTrips = await getTripsNeedingAttention();
    List<Map<String, dynamic>> alerts = [];

    for (final trip in upcomingTrips) {
      try {
        final weatherData = await _weatherService.getWeatherForecast(trip['location']);
        if (!weatherData.containsKey('error') && _weatherService.hasBadWeather(weatherData)) {
          final departDate = DateTime.parse(trip['departDay']);
          final returnDate = DateTime.parse(trip['returnDay']);
          final weatherDesc = _weatherService.getWeatherDescriptionForDateRange(weatherData, departDate, returnDate);

          alerts.add({
            'tripId': trip['id'],
            'location': trip['location'],
            'alertType': 'weather',
            'severity': 'high',
            'title': 'Weather Alert for ${trip['location']}',
            'message': weatherDesc,
            'daysUntilTrip': trip['daysUntilTrip'],
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('Error checking weather for ${trip['location']}: $e');
      }
    }

    return alerts;
  }

  // Get timeline events (reminders, alerts, etc.)
  Future<List<Map<String, dynamic>>> getTimelineEvents() async {
    final trips = await getTripsWithStatus();
    List<Map<String, dynamic>> events = [];

    for (final trip in trips) {
      final daysUntilTrip = trip['daysUntilTrip'] as int;
      final location = trip['location'];
      final tripId = trip['id'];

      // Generate timeline events based on days until trip
      if (daysUntilTrip == 0) {
        events.add(_createTimelineEvent(
          tripId: tripId,
          location: location,
          type: 'departure',
          title: 'Trip Departure Day! ✈️',
          message: 'Your trip to $location starts today! Have an amazing time!',
          urgency: 'critical',
          daysUntilTrip: daysUntilTrip,
        ));
      } else if (daysUntilTrip == 1) {
        events.add(_createTimelineEvent(
          tripId: tripId,
          location: location,
          type: 'tomorrow',
          title: 'Trip Tomorrow! 🚀',
          message: 'Your trip to $location starts tomorrow. Final preparations!',
          urgency: 'high',
          daysUntilTrip: daysUntilTrip,
        ));
      } else if (daysUntilTrip == 3) {
        events.add(_createTimelineEvent(
          tripId: tripId,
          location: location,
          type: '3days',
          title: 'Trip in 3 Days! ⏰',
          message: 'Your trip to $location is in 3 days. Time to start packing!',
          urgency: 'medium',
          daysUntilTrip: daysUntilTrip,
        ));
      } else if (daysUntilTrip == 7) {
        events.add(_createTimelineEvent(
          tripId: tripId,
          location: location,
          type: 'week',
          title: 'Trip Next Week! 📅',
          message: 'Your trip to $location is in a week. Time to start planning!',
          urgency: 'low',
          daysUntilTrip: daysUntilTrip,
        ));
      }
    }

    // Sort events by urgency and days until trip
    events.sort((a, b) {
      final urgencyOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
      final urgencyA = urgencyOrder[a['urgency']] ?? 4;
      final urgencyB = urgencyOrder[b['urgency']] ?? 4;

      if (urgencyA != urgencyB) {
        return urgencyA.compareTo(urgencyB);
      }

      return (a['daysUntilTrip'] as int).compareTo(b['daysUntilTrip'] as int);
    });

    return events;
  }

  // Save user interaction with timeline
  Future<void> markEventAcknowledged(String tripId, String eventType) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = 'acknowledged_events_$tripId';
    final List<String> acknowledged = prefs.getStringList(key) ?? [];
    if (!acknowledged.contains(eventType)) {
      acknowledged.add(eventType);
      await prefs.setStringList(key, acknowledged);
    }
  }

  // Check if event was acknowledged
  Future<bool> isEventAcknowledged(String tripId, String eventType) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = 'acknowledged_events_$tripId';
    final List<String> acknowledged = prefs.getStringList(key) ?? [];
    return acknowledged.contains(eventType);
  }

  // Get trip statistics
  Future<Map<String, int>> getTripStatistics() async {
    final trips = await getTripsWithStatus();

    int upcoming = 0;
    int active = 0;
    int completed = 0;
    int thisMonth = 0;

    final now = DateTime.now();

    for (final trip in trips) {
      if (trip['isUpcoming']) upcoming++;
      if (trip['isActive']) active++;
      if (trip['isPast']) completed++;

      final departDate = DateTime.parse(trip['departDay']);
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
  }

  // Helper methods
  String _getTripStatus(int daysUntilTrip, bool isActive, bool isPast) {
    if (isActive) return 'active';
    if (isPast) return 'completed';
    if (daysUntilTrip == 0) return 'today';
    if (daysUntilTrip == 1) return 'tomorrow';
    if (daysUntilTrip <= 7) return 'soon';
    return 'upcoming';
  }

  int _getTripUrgency(int daysUntilTrip, bool isActive) {
    if (isActive) return 5; // Highest priority
    if (daysUntilTrip == 0) return 4;
    if (daysUntilTrip == 1) return 3;
    if (daysUntilTrip <= 3) return 2;
    if (daysUntilTrip <= 7) return 1;
    return 0; // Lowest priority
  }

  Map<String, dynamic> _createTimelineEvent({
    required String tripId,
    required String location,
    required String type,
    required String title,
    required String message,
    required String urgency,
    required int daysUntilTrip,
  }) {
    return {
      'tripId': tripId,
      'location': location,
      'type': type,
      'title': title,
      'message': message,
      'urgency': urgency,
      'daysUntilTrip': daysUntilTrip,
      'timestamp': DateTime.now().toIso8601String(),
      'id': '${tripId}_$type',
    };
  }
}