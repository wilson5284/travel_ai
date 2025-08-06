import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/weather_service.dart';
import '../services/trip_timeline_service.dart'; // Add this import
import '../widgets/bottom_nav_bar.dart';

class TripTimelineScreen extends StatefulWidget {
  const TripTimelineScreen({super.key});

  @override
  State<TripTimelineScreen> createState() => _TripTimelineScreenState();
}

class _TripTimelineScreenState extends State<TripTimelineScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();
  final TripTimelineService _timelineService = TripTimelineService(); // Add this

  List<Map<String, dynamic>> _allTrips = []; // Store all trips
  List<Map<String, dynamic>> _filteredTrips = []; // Currently displayed trips
  Map<String, Map<String, dynamic>> _weatherData = {};
  List<Map<String, dynamic>> _timelineEvents = []; // Add this
  bool _isLoading = true;
  bool _showUpcoming = true; // Toggle between upcoming and completed trips

  // Color scheme (keeping your existing colors)
  final Color _white = Colors.white;
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFE1BEE7);
  final Color _greyText = Colors.grey.shade600;
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _alertRed = const Color(0xFFE53E3E);
  final Color _warningOrange = const Color(0xFFF56500);
  final Color _successGreen = const Color(0xFF38A169);

  @override
  void initState() {
    super.initState();
    _loadTripsAndWeather();
  }

  Future<void> _loadTripsAndWeather() async {
    setState(() => _isLoading = true);

    try {
      // Use the timeline service instead of direct firestore calls
      final trips = await _timelineService.getTripsWithStatus();
      final now = DateTime.now();

      // Filter trips (same logic as before)
      final filteredTrips = trips.where((trip) {
        final departDate = DateTime.parse(trip['departDay']);
        final daysDifference = departDate.difference(now).inDays;
        return daysDifference >= -30 && daysDifference <= 365;
      }).toList();

      filteredTrips.sort((a, b) {
        final dateA = DateTime.parse(a['departDay']);
        final dateB = DateTime.parse(b['departDay']);
        return dateA.compareTo(dateB);
      });

      // Load timeline events
      final timelineEvents = await _timelineService.getTimelineEvents();

      // Load weather data for each trip
      Map<String, Map<String, dynamic>> weatherMap = {};
      for (final trip in filteredTrips) {
        try {
          final weather = await _weatherService.getWeatherForecast(trip['location']);
          weatherMap[trip['id']] = weather;
        } catch (e) {
          print('Failed to load weather for ${trip['location']}: $e');
          weatherMap[trip['id']] = {'error': 'Failed to load weather'};
        }
      }

      setState(() {
        _allTrips = filteredTrips;
        _weatherData = weatherMap;
        _timelineEvents = timelineEvents;
        _isLoading = false;
      });

      // Filter trips based on current toggle state
      _filterTrips();

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading trips: $e'),
          backgroundColor: _alertRed,
        ),
      );
    }
  }

  // Filter trips based on upcoming/completed toggle
  void _filterTrips() {
    setState(() {
      if (_showUpcoming) {
        // Show upcoming and active trips
        _filteredTrips = _allTrips.where((trip) {
          return trip['isUpcoming'] == true || trip['isActive'] == true;
        }).toList();
      } else {
        // Show completed trips only
        _filteredTrips = _allTrips.where((trip) {
          return trip['isPast'] == true;
        }).toList();
      }
    });
  }

  // Toggle between upcoming and completed trips
  void _toggleTripView() {
    setState(() {
      _showUpcoming = !_showUpcoming;
    });
    _filterTrips();
  }

  // Add navigation to trip details
  void _navigateToTripDetails(Map<String, dynamic> trip) {
    // Option 1: Navigate to a separate screen (if you have one)
    try {
      Navigator.pushNamed(
          context,
          '/trip-details',
          arguments: {
            'tripId': trip['id'],
            'trip': trip,
          }
      );
    } catch (e) {
      // Option 2: Fallback to dialog if route doesn't exist
      print('Trip details route not found, showing dialog instead: $e');
      _showTripDetailsDialog(trip);
    }
  }

  // Optional: Show trip details in a dialog if you don't have a separate screen
  void _showTripDetailsDialog(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trip['location'] ?? 'Trip Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Departure: ${trip['departDay'] ?? 'Not set'}'),
              Text('Return: ${trip['returnDay'] ?? 'Not set'}'),
              const SizedBox(height: 16),
              if (trip['itinerary'] != null && trip['itinerary'] is List) ...[
                const Text('Full Itinerary:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...((trip['itinerary'] as List).map((day) {
                  if (day == null || day is! Map) return Container();

                  final dayMap = day as Map<String, dynamic>;
                  final dayNumber = dayMap['day']?.toString() ?? '?';
                  final activities = dayMap['activities'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Day $dayNumber:', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (activities != null && activities is List)
                          ...activities.map((activity) {
                            if (activity == null || activity is! Map) return Container();
                            final activityMap = activity as Map<String, dynamic>;
                            final activityName = activityMap['name']?.toString() ?? 'Activity';
                            return Padding(
                              padding: const EdgeInsets.only(left: 12, bottom: 4),
                              child: Text('• $activityName'),
                            );
                          }).where((widget) => widget is! Container).toList()
                        else
                          const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 4),
                            child: Text('• No activities planned'),
                          ),
                      ],
                    ),
                  );
                }).where((widget) => widget is! Container).toList()),
              ] else
                const Text('No itinerary available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3E5F5),
              Color(0xFFFFF5E6),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _mediumPurple))
                  : _filteredTrips.isEmpty
                  ? _buildEmptyState()
                  : _buildTripTimeline(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    final upcomingCount = _allTrips.where((trip) {
      return trip['isUpcoming'] == true || trip['isActive'] == true;
    }).length;

    final completedCount = _allTrips.where((trip) {
      return trip['isPast'] == true;
    }).length;

    final currentCount = _showUpcoming ? upcomingCount : completedCount;
    final currentLabel = _showUpcoming ? 'upcoming trips' : 'completed trips';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Timeline',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  Text(
                    '$currentCount $currentLabel',
                    style: TextStyle(
                      fontSize: 14,
                      color: _greyText,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadTripsAndWeather,
                icon: Icon(Icons.refresh, color: _darkPurple),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle buttons
          Container(
            decoration: BoxDecoration(
              color: _lightPurple.withOpacity(0.3),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_showUpcoming) _toggleTripView();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showUpcoming ? _mediumPurple : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upcoming,
                            size: 18,
                            color: _showUpcoming ? _white : _greyText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Upcoming ($upcomingCount)',
                            style: TextStyle(
                              color: _showUpcoming ? _white : _greyText,
                              fontWeight: _showUpcoming ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_showUpcoming) _toggleTripView();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showUpcoming ? _mediumPurple : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 18,
                            color: !_showUpcoming ? _white : _greyText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Completed ($completedCount)',
                            style: TextStyle(
                              color: !_showUpcoming ? _white : _greyText,
                              fontWeight: !_showUpcoming ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showUpcoming ? Icons.upcoming : Icons.history,
            size: 80,
            color: _greyText,
          ),
          const SizedBox(height: 16),
          Text(
            _showUpcoming ? 'No Upcoming Trips' : 'No Completed Trips',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _darkPurple,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _showUpcoming
                  ? 'Start planning your next adventure! Your upcoming trips will appear here with weather alerts and timeline.'
                  : 'Your completed trips will show up here once you finish them. Switch to "Upcoming" to plan new adventures!',
              style: TextStyle(fontSize: 16, color: _greyText),
              textAlign: TextAlign.center,
            ),
          ),
          if (!_showUpcoming && _allTrips.where((trip) => trip['isUpcoming'] == true || trip['isActive'] == true).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: _toggleTripView,
                icon: const Icon(Icons.upcoming),
                label: const Text('View Upcoming Trips'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mediumPurple,
                  foregroundColor: _white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripTimeline() {
    return RefreshIndicator(
      onRefresh: _loadTripsAndWeather,
      color: _mediumPurple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTrips.length,
        itemBuilder: (context, index) {
          final trip = _filteredTrips[index];
          final weather = _weatherData[trip['id']] ?? {};
          return _buildTripCard(trip, weather, index);
        },
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, Map<String, dynamic> weather, int index) {
    // Use the service data instead of calculating manually
    final daysUntilTrip = trip['daysUntilTrip'] as int;
    final isUpcoming = trip['isUpcoming'] as bool;
    final isActive = trip['isActive'] as bool;
    final isPast = trip['isPast'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: isActive ? Border.all(color: _successGreen, width: 3) : null,
      ),
      child: Column(
        children: [
          // Trip header with status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [_successGreen.withOpacity(0.1), _successGreen.withOpacity(0.05)]
                    : isPast
                    ? [_greyText.withOpacity(0.1), _greyText.withOpacity(0.05)]
                    : [_lightPurple.withOpacity(0.3), _lightPurple.withOpacity(0.1)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.flight_takeoff : isPast ? Icons.flight_land : Icons.event,
                      color: isActive ? _successGreen : isPast ? _greyText : _mediumPurple,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip['location'],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _darkPurple,
                            ),
                          ),
                          Text(
                            '${DateFormat('MMM dd').format(DateTime.parse(trip['departDay']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(trip['returnDay']))}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _greyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(isActive, isPast, daysUntilTrip),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimelineStatus(daysUntilTrip, isActive, isPast),
              ],
            ),
          ),

          // Weather and alerts section
          if (weather.isNotEmpty) _buildWeatherSection(trip, weather, daysUntilTrip),

          // Trip details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Safe check for itinerary existence
                if (trip['itinerary'] != null) _buildItineraryPreview(trip['itinerary']),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: _greyText),
                    const SizedBox(width: 8),
                    Text(
                      'Duration: ${DateTime.parse(trip['returnDay']).difference(DateTime.parse(trip['departDay'])).inDays + 1} days',
                      style: TextStyle(fontSize: 14, color: _greyText),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _navigateToTripDetails(trip), // Fixed navigation
                      child: Text('View Details', style: TextStyle(color: _mediumPurple)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Keep all your existing methods (_buildStatusChip, _buildTimelineStatus, etc.)
  // ... (rest of your existing methods remain the same)

  Widget _buildStatusChip(bool isActive, bool isPast, int daysUntilTrip) {
    String text;
    Color color;
    Color bgColor;

    if (isActive) {
      text = 'ACTIVE';
      color = _white;
      bgColor = _successGreen;
    } else if (isPast) {
      text = 'COMPLETED';
      color = _white;
      bgColor = _greyText;
    } else if (daysUntilTrip == 0) {
      text = 'TODAY';
      color = _white;
      bgColor = _alertRed;
    } else if (daysUntilTrip == 1) {
      text = 'TOMORROW';
      color = _white;
      bgColor = _warningOrange;
    } else if (daysUntilTrip <= 7) {
      text = '${daysUntilTrip}D';
      color = _white;
      bgColor = _mediumPurple;
    } else {
      text = '${daysUntilTrip}D';
      color = _mediumPurple;
      bgColor = _lightPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimelineStatus(int daysUntilTrip, bool isActive, bool isPast) {
    String message;
    IconData icon;
    Color color;

    if (isActive) {
      message = 'Enjoy your trip! Have an amazing time! 🎉';
      icon = Icons.celebration;
      color = _successGreen;
    } else if (isPast) {
      message = 'Hope you had a wonderful trip! ✨';
      icon = Icons.sentiment_very_satisfied;
      color = _greyText;
    } else if (daysUntilTrip == 0) {
      message = 'Your trip starts today! Get ready! 🚀';
      icon = Icons.rocket_launch;
      color = _alertRed;
    } else if (daysUntilTrip == 1) {
      message = 'Trip starts tomorrow! Final preparations! ⏰';
      icon = Icons.alarm;
      color = _warningOrange;
    } else if (daysUntilTrip <= 3) {
      message = 'Trip starting soon! Time to pack! 🎒';
      icon = Icons.luggage;
      color = _mediumPurple;
    } else if (daysUntilTrip <= 7) {
      message = 'Trip next week! Start planning! 📋';
      icon = Icons.event_note;
      color = _mediumPurple;
    } else {
      message = 'Trip coming up! Keep an eye on weather! 👀';
      icon = Icons.visibility;
      color = _greyText;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection(Map<String, dynamic> trip, Map<String, dynamic> weather, int daysUntilTrip) {
    if (weather.containsKey('error') || daysUntilTrip > 14) {
      return Container();
    }

    final departDate = DateTime.parse(trip['departDay']);
    final returnDate = DateTime.parse(trip['returnDay']);
    final hasBadWeather = _weatherService.hasBadWeather(weather);
    final weatherDesc = _weatherService.getWeatherDescriptionForDateRange(weather, departDate, returnDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasBadWeather ? _alertRed.withOpacity(0.1) : _successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBadWeather ? _alertRed.withOpacity(0.3) : _successGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasBadWeather ? Icons.warning_amber : Icons.wb_sunny,
            color: hasBadWeather ? _alertRed : _successGreen,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasBadWeather ? 'Weather Alert!' : 'Great Weather!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasBadWeather ? _alertRed : _successGreen,
                    fontSize: 14,
                  ),
                ),
                Text(
                  weatherDesc,
                  style: TextStyle(
                    color: _greyText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryPreview(dynamic itineraryData) {
    // Safe null check and casting
    if (itineraryData == null) return Container();

    List<dynamic> itinerary;
    try {
      itinerary = itineraryData is List ? itineraryData : [];
    } catch (e) {
      print('Error casting itinerary: $e');
      return Container();
    }

    if (itinerary.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Itinerary Preview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkPurple,
          ),
        ),
        const SizedBox(height: 8),
        ...itinerary.take(3).map((day) {
          // Safe access to day data
          if (day == null || day is! Map) {
            return Container();
          }

          final dayMap = day as Map<String, dynamic>;
          final dayNumber = dayMap['day']?.toString() ?? '?';

          // Safe access to activities
          String activityText = 'Activities planned';
          try {
            final activities = dayMap['activities'];
            if (activities != null && activities is List && activities.isNotEmpty) {
              final firstActivity = activities[0];
              if (firstActivity != null && firstActivity is Map) {
                activityText = firstActivity['name']?.toString() ?? 'Activities planned';
              }
            }
          } catch (e) {
            print('Error accessing activities: $e');
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _mediumPurple,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Day $dayNumber: $activityText',
                    style: TextStyle(fontSize: 14, color: _greyText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).where((widget) => widget is! Container || (widget as Container).child != null).toList(),
        if (itinerary.length > 3)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '+ ${itinerary.length - 3} more days',
              style: TextStyle(fontSize: 12, color: _greyText, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}