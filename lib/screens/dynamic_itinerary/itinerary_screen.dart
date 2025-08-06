// lib/screens/itinerary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController _interestsController = TextEditingController(); // Added interests controller

  DateTime? _departDay;
  DateTime? _returnDay;
  TimeOfDay? _departTime;
  TimeOfDay? _returnTime;

  bool isLoading = false;
  bool isFormVisible = false; // Form is hidden by default

  final WeatherService _weatherService = WeatherService();
  final FirestoreService _firestoreService = FirestoreService();

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
    isFormVisible = false; // Form hidden by default
  }

  // --- Date Picker Logic ---
  Future<void> _selectDate(BuildContext context, bool isDepartDate) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isDepartDate
          ? (_departDay ?? now)
          : (_returnDay ?? (_departDay ?? now)),
      firstDate: now.subtract(const Duration(days: 0)), // Disable past dates
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
          // Ensure return date is not before departure date
          if (_returnDay != null && _returnDay!.isBefore(_departDay!)) {
            _returnDay = _departDay;
          }
        } else {
          // Ensure return date is not before departure date
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

  // --- Time Picker Logic ---
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
      // Check if the departure date is the current day
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
          _departTime = TimeOfDay.now(); // Reset to current time
        }
      }
      // Check if return time is before departure time on the same day
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

  // --- Itinerary Generation Logic ---
  void _generateItinerary() async {
    if (!_isFormFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields correctly.', style: TextStyle(color: _white)),
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
        _showWeatherReminderDialog(location, "Weather data could not be fetched due to an error. Please verify weather conditions independently.");
      } else {
        if (_weatherService.hasBadWeather(weatherData)) {
          final weatherDescription = _weatherService.getWeatherDescriptionForDateRange(weatherData, departDay, returnDay);
          _showWeatherReminderDialog(location, "Warning: Bad weather conditions expected during your trip ($weatherDescription). Consider adjusting your plans.");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Good weather expected for your trip to $location!', style: TextStyle(color: _white)),
              backgroundColor: _mediumPurple,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check weather due to a network error: $e. Proceeding with itinerary generation.', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _showWeatherReminderDialog(location, "Weather data could not be fetched due to a network error. Please verify weather conditions independently.");
    }

    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
    final String departDayStr = dateFormatter.format(departDay);
    final String returnDayStr = dateFormatter.format(returnDay);
    final String departTimeStr = _departTime!.format(context);
    final String returnTimeStr = _returnTime!.format(context);

    try {
      final result = await GeminiService.generateItinerary(
        location,
        departDayStr,
        returnDayStr,
        departTimeStr,
        returnTimeStr,
        daysBetween,
        double.parse(_budgetController.text),
        _interestsController.text, // Pass the interests here
      );

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'].toString(), style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        final Map<String, dynamic> generatedTripDetails = {
          'location': location,
          'departDay': departDayStr,
          'returnDay': returnDayStr,
          'departTime': departTimeStr,
          'returnTime': returnTimeStr,
          'totalDays': daysBetween,
          'budget': double.parse(_budgetController.text),
          'interests': _interestsController.text,
          'itinerary': (result['itinerary'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [],
          'suggestions': (result['suggestions'] as List<dynamic>?)?.map((item) => item as String).toList() ?? [],
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestoreService.saveItinerary(generatedTripDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Itinerary generated and saved to history!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewItineraryDetailScreen(tripDetails: generatedTripDetails, isNewTrip: true),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating itinerary: $e', style: TextStyle(color: _white)),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _budgetController.dispose();
    _interestsController.dispose();
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
                      'Let our AI create personalized travel itineraries tailored to your preferences, budget, and interests. Get weather updates, budget management, and detailed day-by-day plans.',
                      style: TextStyle(
                        fontSize: 16,
                        color: _greyText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Main Action Buttons
                    if (!isFormVisible) ...[
                      // Generate Itinerary Button
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
                      const SizedBox(height: 30),

                      // Features Info
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Features:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem(Icons.wb_sunny_outlined, 'Weather Integration'),
                            _buildFeatureItem(Icons.account_balance_wallet_outlined, 'Budget Management'),
                            _buildFeatureItem(Icons.star_outline, 'Personalized Recommendations'),
                            _buildFeatureItem(Icons.schedule_outlined, 'Detailed Day Plans'),
                          ],
                        ),
                      ),
                    ],

                    // Form Section (appears when Generate Itinerary is clicked)
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
                            'Create Your Itinerary',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _darkPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.8),
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
                          children: [
                            TextField(
                              controller: _locationController,
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              onChanged: (_) => setState(() {}),
                              decoration: _buildInputDecoration(
                                "Enter Location",
                                prefixIcon: Icons.location_on,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _budgetController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              decoration: _buildInputDecoration(
                                "Enter Budget (RM)",
                                prefixIcon: Icons.monetization_on,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _interestsController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: _darkPurple, fontSize: 16),
                              decoration: _buildInputDecoration(
                                "Interests (e.g., food, nature)",
                                prefixIcon: Icons.star,
                              ),
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
                                          "Departure Time",
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
                                          "Return Time",
                                          prefixIcon: Icons.access_time,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
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
                                      'Generate Itinerary',
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          "Your generated itinerary will appear in a new screen and be saved to history.",
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
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
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