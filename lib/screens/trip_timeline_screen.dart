import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/weather_service.dart';
import '../services/trip_timeline_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'dynamic_itinerary/view_itinerary_detail_screen.dart';

class TripTimelineScreen extends StatefulWidget {
  const TripTimelineScreen({super.key});

  @override
  State<TripTimelineScreen> createState() => _TripTimelineScreenState();
}

class _TripTimelineScreenState extends State<TripTimelineScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();
  final TripTimelineService _timelineService = TripTimelineService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _allTrips = [];
  List<Map<String, dynamic>> _filteredTrips = [];
  Map<String, Map<String, dynamic>> _weatherData = {};
  List<Map<String, dynamic>> _timelineEvents = [];
  bool _isLoading = true;
  bool _showUpcoming = true;

  // User-specific variables
  User? _currentUser;
  bool _isUserAuthenticated = false;

  // Color scheme
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
    _checkUserAuthentication();
  }

  // Check if user is authenticated before loading trips
  void _checkUserAuthentication() {
    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      setState(() {
        _isUserAuthenticated = true;
      });
      _loadTripsAndWeather();
    } else {
      setState(() {
        _isUserAuthenticated = false;
        _isLoading = false;
      });
      _showAuthenticationRequiredDialog();
    }
  }

  // Show dialog when user is not authenticated
  void _showAuthenticationRequiredDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Authentication Required',
                style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: _mediumPurple),
                  const SizedBox(height: 16),
                  const Text(
                    'You need to be logged in to view your trip timeline. Please sign in to access your personal itinerary history.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  child: const Text('Go Back'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mediumPurple,
                    foregroundColor: _white,
                  ),
                  child: const Text('Sign In'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  Future<void> _loadTripsAndWeather() async {
    setState(() => _isLoading = true);

    try {
      // Use the timeline service to get user-specific trips
      final trips = await _timelineService.getTripsWithStatus();
      final now = DateTime.now();

      // Filter trips for timeline view (past 30 days to future 365 days)
      final filteredTrips = trips.where((trip) {
        final departDate = DateTime.parse(trip['departDay']);
        final daysDifference = departDate.difference(now).inDays;
        return daysDifference >= -30 && daysDifference <= 365;
      }).toList();

      // Sort trips by departure date for timeline order
      filteredTrips.sort((a, b) {
        final dateA = DateTime.parse(a['departDay']);
        final dateB = DateTime.parse(b['departDay']);
        return dateA.compareTo(dateB);
      });

      // Load timeline events for user
      final timelineEvents = await _timelineService.getTimelineEvents();

      // Load weather data for each upcoming trip
      Map<String, Map<String, dynamic>> weatherMap = {};
      for (final trip in filteredTrips) {
        // Only load weather for upcoming trips within 14 days
        final daysUntil = trip['daysUntilTrip'] as int;
        if (daysUntil >= 0 && daysUntil <= 14) {
          try {
            final weather = await _weatherService.getWeatherForecast(trip['location']);
            weatherMap[trip['id']] = weather;
          } catch (e) {
            print('Failed to load weather for ${trip['location']}: $e');
            weatherMap[trip['id']] = {'error': 'Failed to load weather'};
          }
        }
      }

      setState(() {
        _allTrips = filteredTrips;
        _weatherData = weatherMap;
        _timelineEvents = timelineEvents;
        _isLoading = false;
      });

      _filterTrips();

    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Error loading trips: $e');
    }
  }

  void _filterTrips() {
    setState(() {
      if (_showUpcoming) {
        _filteredTrips = _allTrips.where((trip) {
          return trip['isUpcoming'] == true || trip['isActive'] == true;
        }).toList();
      } else {
        _filteredTrips = _allTrips.where((trip) {
          return trip['isPast'] == true;
        }).toList();
      }
    });
  }

  void _toggleTripView() {
    setState(() {
      _showUpcoming = !_showUpcoming;
    });
    _filterTrips();
  }

  // Navigate to itinerary details page
  void _navigateToItineraryDetails(Map<String, dynamic> trip) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewItineraryDetailScreen(
            tripDetails: trip,
            isNewTrip: false,
          ),
        ),
      ).then((result) {
        // Refresh data when returning from details page
        _loadTripsAndWeather();

        // If trip was deleted, show confirmation
        if (result == true) {
          _showSuccessMessage('Trip deleted successfully!');
        }
      });
    } catch (e) {
      print('Navigation error: $e');
      _showErrorMessage('Unable to open itinerary details. Please try again.');
    }
  }

  // Show error messages to user
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _alertRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show success messages to user
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show authentication required screen if user is not logged in
    if (!_isUserAuthenticated) {
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 100, color: _mediumPurple),
                const SizedBox(height: 24),
                Text(
                  'Authentication Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _darkPurple,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Please sign in to view your personal trip timeline and itinerary history.',
                    style: TextStyle(fontSize: 16, color: _greyText),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mediumPurple,
                    foregroundColor: _white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 3),
      );
    }

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
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _mediumPurple),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your trip timeline...',
                      style: TextStyle(color: _greyText),
                    ),
                  ],
                ),
              )
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

    // Get user display name or email
    final String userDisplayName = _currentUser?.displayName ??
        _currentUser?.email?.split('@')[0] ??
        'User';

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
                    'My Trip Timeline',
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
                  // User indicator
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: _mediumPurple),
                      const SizedBox(width: 4),
                      Text(
                        'Welcome, $userDisplayName',
                        style: TextStyle(
                          fontSize: 12,
                          color: _mediumPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: _darkPurple),
                onSelected: (String value) {
                  switch (value) {
                    case 'refresh':
                      _loadTripsAndWeather();
                      break;
                    case 'logout':
                      _showLogoutConfirmation();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: _darkPurple, size: 20),
                        const SizedBox(width: 8),
                        const Text('Refresh Timeline'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle buttons for upcoming/completed
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

  // Show logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Sign Out',
            style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _greyText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: _white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  // Perform user logout
  Future<void> _performLogout() async {
    try {
      await _auth.signOut();

      // Clear user-specific data
      setState(() {
        _currentUser = null;
        _isUserAuthenticated = false;
        _allTrips.clear();
        _filteredTrips.clear();
        _weatherData.clear();
        _timelineEvents.clear();
      });

      // Navigate to login or home screen
      Navigator.pushReplacementNamed(context, '/login');

    } catch (e) {
      _showErrorMessage('Failed to sign out: $e');
    }
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
                  ? 'Start planning your next adventure! Your upcoming trips will appear here with weather alerts and timeline updates.'
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
                            trip['location'] ?? 'Unknown Location',
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

          // Weather section (only for upcoming trips within 14 days)
          if (weather.isNotEmpty) _buildWeatherSection(trip, weather, daysUntilTrip),

          // Trip actions section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Trip duration info
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: _greyText),
                    const SizedBox(width: 8),
                    Text(
                      'Duration: ${DateTime.parse(trip['returnDay']).difference(DateTime.parse(trip['departDay'])).inDays + 1} days',
                      style: TextStyle(fontSize: 14, color: _greyText),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action button - View Itinerary
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToItineraryDetails(trip),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View Itinerary Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mediumPurple,
                      foregroundColor: _white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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
}