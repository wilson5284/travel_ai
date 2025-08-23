// lib/screens/itinerary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/gemini_service.dart';
import '../../services/weather_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'history_screen.dart';
import 'view_itinerary_detail_screen.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreen();
}

class _ItineraryScreen extends State<ItineraryScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _accommodationController = TextEditingController();
  final TextEditingController _transportController = TextEditingController();

  DateTime? _departDay;
  DateTime? _returnDay;
  TimeOfDay? _departTime;
  TimeOfDay? _returnTime;

  bool isLoading = false;
  bool isFormVisible = false;

  // Travel pace preference
  String _travelPace = 'moderate';

  // Meal preferences
  List<String> _mealPreferences = [];

  // Activity preferences with categories
  Map<String, List<String>> _selectedInterests = {
    'Culture & History': [],
    'Food & Dining': [],
    'Shopping': [],
    'Nature & Outdoors': [],
    'Entertainment': [],
    'Adventure & Sports': [],
    'Wellness & Relaxation': [],
    'Nightlife': [],
  };

  // Predefined interest options
  final Map<String, List<String>> _interestOptions = {
    'Culture & History': ['Museums', 'Temples', 'Historical Sites', 'Art Galleries', 'Cultural Shows', 'Local Traditions'],
    'Food & Dining': ['Street Food', 'Fine Dining', 'Local Cuisine', 'Cafes', 'Food Markets', 'Cooking Classes'],
    'Shopping': ['Local Markets', 'Fashion Streets', 'Malls', 'Vintage Shops', 'Souvenirs', 'Designer Brands'],
    'Nature & Outdoors': ['Beaches', 'Mountains', 'Parks', 'Gardens', 'Hiking', 'Wildlife'],
    'Entertainment': ['Theme Parks', 'Shows', 'Concerts', 'Festivals', 'Movies', 'Sports Events'],
    'Adventure & Sports': ['Water Sports', 'Extreme Sports', 'Rock Climbing', 'Diving', 'Cycling', 'Zip-lining'],
    'Wellness & Relaxation': ['Spa', 'Yoga', 'Meditation', 'Hot Springs', 'Massage', 'Wellness Retreats'],
    'Nightlife': ['Bars', 'Clubs', 'Night Markets', 'Rooftop Lounges', 'Live Music', 'Pub Crawls'],
  };

  final WeatherService _weatherService = WeatherService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color scheme
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkerOffWhite = const Color(0xFFEBEBEB);
  final Color _violet = const Color(0xFF6A1B9A);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;

  User? get currentUser => _auth.currentUser;

  bool get _isFormFilled {
    return _locationController.text.isNotEmpty &&
        _budgetController.text.isNotEmpty &&
        double.tryParse(_budgetController.text) != null &&
        _departDay != null &&
        _returnDay != null &&
        _departTime != null &&
        _returnTime != null;
  }

  @override
  void initState() {
    super.initState();
    isFormVisible = false;
  }

  // Date Picker Logic
  Future<void> _selectDate(BuildContext context, bool isDepartDate) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isDepartDate
          ? (_departDay ?? now)
          : (_returnDay ?? (_departDay ?? now)),
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _darkPurple,
              onPrimary: _white,
              onSurface: _darkPurple,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _mediumPurple,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        if (isDepartDate) {
          _departDay = pickedDate;
          if (_returnDay != null && _returnDay!.isBefore(_departDay!)) {
            _returnDay = _departDay;
          }
        } else {
          if (_departDay != null && pickedDate.isBefore(_departDay!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Return date cannot be before departure date.',
                  style: TextStyle(color: _white),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else {
            _returnDay = pickedDate;
          }
        }
        _validateTimesIfSameDay();
      });
    }
  }

  // Time Picker Logic
  Future<void> _selectTime(BuildContext context, bool isDepartTime) async {
    final TimeOfDay now = TimeOfDay.now();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: isDepartTime ? (_departTime ?? now) : (_returnTime ?? now),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _darkPurple,
              onPrimary: _white,
              onSurface: _darkPurple,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _mediumPurple,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        if (isDepartTime) {
          _departTime = pickedTime;
        } else {
          _returnTime = pickedTime;
        }
        _validateTimesIfSameDay();
      });
    }
  }

  void _validateTimesIfSameDay() {
    if (_departDay != null && _returnDay != null && _departTime != null && _returnTime != null) {
      final now = DateTime.now();
      if (_departDay!.year == now.year && _departDay!.month == now.month && _departDay!.day == now.day) {
        if (_departTime!.hour < now.hour || (_departTime!.hour == now.hour && _departTime!.minute < now.minute)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Departure time cannot be in the past.',
                style: TextStyle(color: _white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          _departTime = TimeOfDay.now();
        }
      }
      if (_departDay!.year == _returnDay!.year &&
          _departDay!.month == _returnDay!.month &&
          _departDay!.day == _returnDay!.day) {
        final DateTime departDateTime = DateTime(_departDay!.year, _departDay!.month, _departDay!.day, _departTime!.hour, _departTime!.minute);
        final DateTime returnDateTime = DateTime(_returnDay!.year, _returnDay!.month, _returnDay!.day, _returnTime!.hour, _returnTime!.minute);

        if (returnDateTime.isBefore(departDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Return time cannot be before departure time on the same day. Adjusted to departure time.', style: TextStyle(color: _white)),
              backgroundColor: Colors.redAccent,
            ),
          );
          _returnTime = _departTime;
        }
      }
    }
  }

  // Get formatted preferences string
  String _getFormattedPreferences() {
    List<String> allPreferences = [];

    // Add selected interests
    _selectedInterests.forEach((category, items) {
      if (items.isNotEmpty) {
        allPreferences.addAll(items);
      }
    });

    // Add custom interests from text field
    if (_interestsController.text.isNotEmpty) {
      allPreferences.add(_interestsController.text);
    }

    // Add meal preferences
    if (_mealPreferences.isNotEmpty) {
      allPreferences.addAll(_mealPreferences.map((meal) => 'Food: $meal'));
    }

    return allPreferences.join(', ');
  }

  // Generate Itinerary
  void _generateItinerary() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to generate itineraries.', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!_isFormFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields.', style: TextStyle(color: _white)),
          backgroundColor: _mediumPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String location = _locationController.text;
    final DateTime departDay = _departDay!;
    final DateTime returnDay = _returnDay!;
    final int daysBetween = returnDay.difference(departDay).inDays + 1;

    // Weather Check
    try {
      final weatherData = await _weatherService.getWeatherForecast(location);
      if (weatherData.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weather check encountered an error: ${weatherData['error']}. Proceeding with itinerary generation.', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        if (_weatherService.hasBadWeather(weatherData)) {
          final weatherDescription = _weatherService.getWeatherDescriptionForDateRange(weatherData, departDay, returnDay);
          _showWeatherReminderDialog(location, "Warning: Bad weather conditions expected during your trip ($weatherDescription). Consider adjusting your plans.");
        }
      }
    } catch (e) {
      print('Weather check error: $e');
    }

    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
    final String departDayStr = dateFormatter.format(departDay);
    final String returnDayStr = dateFormatter.format(returnDay);
    final String departTimeStr = _departTime!.format(context);
    final String returnTimeStr = _returnTime!.format(context);

    // Compile all preferences
    final String formattedPreferences = _getFormattedPreferences();

    // Generate Itinerary with enhanced preferences
    try {
      final result = await GeminiService.generateEnhancedItinerary(
        location: location,
        departDay: departDayStr,
        returnDay: returnDayStr,
        departTime: departTimeStr,
        returnTime: returnTimeStr,
        daysBetween: daysBetween,
        budget: double.parse(_budgetController.text),
        interests: formattedPreferences,
        travelPace: _travelPace,
        accommodationType: _accommodationController.text.isNotEmpty ? _accommodationController.text : 'any',
        transportPreference: _transportController.text.isNotEmpty ? _transportController.text : 'any',
        mealPreferences: _mealPreferences,
        selectedCategories: _selectedInterests,
      );

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error'].toString()}', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Prepare trip details
      final Map<String, dynamic> generatedTripDetails = {
        'userId': currentUser!.uid,
        'location': location,
        'departDay': departDayStr,
        'returnDay': returnDayStr,
        'departTime': departTimeStr,
        'returnTime': returnTimeStr,
        'totalDays': daysBetween,
        'budget': double.parse(_budgetController.text),
        'interests': formattedPreferences,
        'travelPace': _travelPace,
        'accommodation': _accommodationController.text,
        'transport': _transportController.text,
        'itinerary': (result['itinerary'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [],
        'suggestions': (result['suggestions'] as List<dynamic>?)?.map((item) => item as String).toList() ?? [],
      };

      // Save using FirestoreService
      try {
        final String docId = await _firestoreService.saveItinerary(generatedTripDetails);
        generatedTripDetails['id'] = docId;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Personalized itinerary generated and saved!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Navigate to detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewItineraryDetailScreen(tripDetails: generatedTripDetails, isNewTrip: true),
          ),
        );

      } catch (firestoreError) {
        print('Firestore save error: $firestoreError');
        // Still navigate to show the generated itinerary
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewItineraryDetailScreen(tripDetails: generatedTripDetails, isNewTrip: true),
          ),
        );
      }

    } catch (geminiError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating itinerary: $geminiError', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showWeatherReminderDialog(String location, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white,
          title: Text('Weather Alert for $location', style: TextStyle(color: _darkPurple)),
          content: Text(message, style: TextStyle(color: _greyText)),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: _mediumPurple)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String labelText, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: _darkPurple.withOpacity(0.8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _mediumPurple) : null,
      filled: true,
      fillColor: _lightBeige.withOpacity(0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _mediumPurple.withOpacity(0.4), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _mediumPurple.withOpacity(0.4), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkPurple, width: 2.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // Build interest selection chips
  Widget _buildInterestChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _interestOptions.entries.map((entry) {
        final category = entry.key;
        final options = entry.value;
        final selectedInCategory = _selectedInterests[category] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: options.map((interest) {
                final isSelected = selectedInCategory.contains(interest);
                return FilterChip(
                  label: Text(
                    interest,
                    style: TextStyle(
                      color: isSelected ? _white : _darkPurple,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests[category]!.add(interest);
                      } else {
                        _selectedInterests[category]!.remove(interest);
                      }
                    });
                  },
                  backgroundColor: _lightPurple.withOpacity(0.5),
                  selectedColor: _mediumPurple,
                  checkmarkColor: _white,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _budgetController.dispose();
    _interestsController.dispose();
    _accommodationController.dispose();
    _transportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canGenerate = _isFormFilled;

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
            Container(
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
                  colors: [
                    Colors.white,
                    Colors.white,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'Travel AI Assistant',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  Spacer(),
                  if (currentUser != null) ...[
                    Icon(Icons.person, color: _mediumPurple, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Logged In',
                      style: TextStyle(
                        fontSize: 12,
                        color: _mediumPurple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    if (!isFormVisible) ...[
                      Text(
                        'Plan Your Perfect Adventure',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _darkPurple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Let our AI create highly personalized travel itineraries based on your specific preferences, interests, and travel style.',
                        style: TextStyle(
                          fontSize: 16,
                          color: _greyText,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Main Action Buttons
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_darkPurple, _mediumPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                isFormVisible = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: _white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Generate New Itinerary',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // View History Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const HistoryScreen()),
                            );
                          },
                          icon: const Icon(Icons.history, color: Colors.white),
                          label: const Text(
                            'View Itinerary History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mediumPurple,
                            foregroundColor: _white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 3,
                            shadowColor: Colors.deepPurple.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],

                    // Form Section
                    if (isFormVisible) ...[
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                isFormVisible = false;
                              });
                            },
                            icon: Icon(Icons.arrow_back, color: _darkPurple),
                          ),
                          Text(
                            'Create Your Personalized Itinerary',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _darkPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Basic Information Section
                      Container(
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📍 Basic Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _locationController,
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              onChanged: (_) => setState(() {}),
                              decoration: _buildInputDecoration(
                                "Enter Location (e.g., Bangkok, Paris)",
                                prefixIcon: Icons.location_on,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _budgetController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              decoration: _buildInputDecoration(
                                "Enter Total Budget (RM)",
                                prefixIcon: Icons.monetization_on,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, true),
                                    child: AbsorbPointer(
                                      child: TextField(
                                        style: TextStyle(color: _darkPurple, fontSize: 16),
                                        controller: TextEditingController(
                                          text: _departDay == null
                                              ? ''
                                              : DateFormat('yyyy-MM-dd').format(_departDay!),
                                        ),
                                        decoration: _buildInputDecoration(
                                          "Departure Date",
                                          prefixIcon: Icons.calendar_today,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectTime(context, true),
                                    child: AbsorbPointer(
                                      child: TextField(
                                        style: TextStyle(color: _darkPurple, fontSize: 16),
                                        controller: TextEditingController(
                                          text: _departTime == null
                                              ? ''
                                              : _departTime!.format(context),
                                        ),
                                        decoration: _buildInputDecoration(
                                          "Time",
                                          prefixIcon: Icons.access_time,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, false),
                                    child: AbsorbPointer(
                                      child: TextField(
                                        style: TextStyle(color: _darkPurple, fontSize: 16),
                                        controller: TextEditingController(
                                          text: _returnDay == null
                                              ? ''
                                              : DateFormat('yyyy-MM-dd').format(_returnDay!),
                                        ),
                                        decoration: _buildInputDecoration(
                                          "Return Date",
                                          prefixIcon: Icons.calendar_today,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectTime(context, false),
                                    child: AbsorbPointer(
                                      child: TextField(
                                        style: TextStyle(color: _darkPurple, fontSize: 16),
                                        controller: TextEditingController(
                                          text: _returnTime == null
                                              ? ''
                                              : _returnTime!.format(context),
                                        ),
                                        decoration: _buildInputDecoration(
                                          "Time",
                                          prefixIcon: Icons.access_time,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Travel Preferences Section
                      Container(
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎯 Travel Preferences',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Travel Pace
                            Text(
                              'Travel Pace',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Relaxed', style: TextStyle(fontSize: 13)),
                                    value: 'relaxed',
                                    groupValue: _travelPace,
                                    onChanged: (value) {
                                      setState(() {
                                        _travelPace = value!;
                                      });
                                    },
                                    activeColor: _mediumPurple,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Moderate', style: TextStyle(fontSize: 13)),
                                    value: 'moderate',
                                    groupValue: _travelPace,
                                    onChanged: (value) {
                                      setState(() {
                                        _travelPace = value!;
                                      });
                                    },
                                    activeColor: _mediumPurple,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Packed', style: TextStyle(fontSize: 13)),
                                    value: 'packed',
                                    groupValue: _travelPace,
                                    onChanged: (value) {
                                      setState(() {
                                        _travelPace = value!;
                                      });
                                    },
                                    activeColor: _mediumPurple,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Accommodation & Transport
                            TextField(
                              controller: _accommodationController,
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              decoration: _buildInputDecoration(
                                "Accommodation Type (e.g., Hotel, Hostel, Airbnb)",
                                prefixIcon: Icons.hotel,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _transportController,
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              decoration: _buildInputDecoration(
                                "Transport Preference (e.g., Public, Taxi, Walk)",
                                prefixIcon: Icons.directions_car,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Meal Preferences
                            Text(
                              'Dietary Preferences',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              children: ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free', 'None'].map((meal) {
                                final isSelected = _mealPreferences.contains(meal);
                                return FilterChip(
                                  label: Text(meal, style: TextStyle(color: isSelected ? _white : _darkPurple, fontSize: 12)),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        _mealPreferences.add(meal);
                                      } else {
                                        _mealPreferences.remove(meal);
                                      }
                                    });
                                  },
                                  backgroundColor: _lightPurple.withOpacity(0.5),
                                  selectedColor: _mediumPurple,
                                  checkmarkColor: _white,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Interests Section
                      Container(
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✨ Select Your Interests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInterestChips(),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _interestsController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              maxLines: 2,
                              decoration: _buildInputDecoration(
                                "Add custom interests (e.g., Bangkok hip-hop fashion, street art)",
                                prefixIcon: Icons.add_circle_outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: AbsorbPointer(
                          absorbing: isLoading || !canGenerate,
                          child: Opacity(
                            opacity: (isLoading || !canGenerate) ? 0.6 : 1.0,
                            child: ElevatedButton.icon(
                              onPressed: _generateItinerary,
                              icon: isLoading
                                  ? const SizedBox(width: 0)
                                  : const Icon(Icons.auto_awesome, color: Colors.white),
                              label: isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Generate Personalized Itinerary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _darkPurple,
                                foregroundColor: _white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 3,
                                shadowColor: Colors.deepPurple.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          "Your personalized itinerary will be generated based on all your preferences and saved to your collection.",
                          style: TextStyle(fontWeight: FontWeight.bold, color: _greyText),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: _mediumPurple, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: _greyText,
            ),
          ),
        ],
      ),
    );
  }
}