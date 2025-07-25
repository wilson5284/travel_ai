// lib/screens/itinerary_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  DateTime? _departDay;
  DateTime? _returnDay;
  TimeOfDay? _departTime;
  TimeOfDay? _returnTime;
  bool isLoading = false;
  bool isFormVisible = false;

  // Color scheme (copied from home_screen for consistency)
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
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
    isFormVisible = false;
  }

  Future<void> _selectDate(BuildContext context, bool isDepartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isDepartDate
          ? (_departDay ?? DateTime.now())
          : (_returnDay ?? (_departDay ?? DateTime.now())),
      firstDate: DateTime.now().subtract(const Duration(days: 0)),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _darkPurple, // Header background
              onPrimary: _white, // Header text color
              surface: _offWhite, // Calendar background
              onSurface: _darkPurple, // Calendar text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _mediumPurple, // OK/CANCEL buttons
              ),
            ),
            dialogBackgroundColor: _white, // Dialog background
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
          _returnDay = pickedDate;
          if (_departDay != null && _departDay!.isAfter(_returnDay!)) {
            _departDay = _returnDay;
          }
        }
        _validateTimesIfSameDay();
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isDepartTime) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: isDepartTime ? (_departTime ?? TimeOfDay.now()) : (_returnTime ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _darkPurple, // Header background
              onPrimary: _white, // Header text color
              surface: _offWhite, // Clock/numbers background
              onSurface: _darkPurple, // Clock numbers/text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _mediumPurple, // OK/CANCEL buttons
              ),
            ),
            dialogBackgroundColor: _white, // Dialog background
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
      if (_departDay!.year == _returnDay!.year &&
          _departDay!.month == _returnDay!.month &&
          _departDay!.day == _returnDay!.day) {
        final DateTime departDateTime = DateTime(_departDay!.year, _departDay!.month, _departDay!.day, _departTime!.hour, _departTime!.minute);
        final DateTime returnDateTime = DateTime(_returnDay!.year, _returnDay!.month, _returnDay!.day, _returnTime!.hour, _returnTime!.minute);

        if (returnDateTime.isBefore(departDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Return time cannot be before departure time on the same day. Adjusting return time.')),
          );
          _returnTime = _departTime;
        }
      }
    }
  }

  void _generateItinerary() async {
    if (!_isFormFilled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill in all fields correctly.', style: TextStyle(color: _white)),
        backgroundColor: _mediumPurple,
      ));
      return;
    }

    setState(() => isLoading = true);

    final String location = _locationController.text;
    final DateTime departDay = _departDay!;
    final DateTime returnDay = _returnDay!;
    final int totalDays = returnDay.difference(departDay).inDays + 1;

    final String departDateStr = DateFormat('yyyy-MM-dd').format(departDay);
    final String returnDateStr = DateFormat('yyyy-MM-dd').format(returnDay);
    final String departTimeStr = _departTime!.format(context);
    final String returnTimeStr = _returnTime!.format(context);
    final double budget = double.parse(_budgetController.text);

    try {
      final weatherData = await _weatherService.getWeatherForecast(location);
      final result = await GeminiService.generateItinerary(
        location,
        departDateStr,
        returnDateStr,
        departTimeStr,
        returnTimeStr,
        totalDays,
        budget,
      );

      if (result.containsKey('error')) {
        throw result['error'];
      }

      final itinerary = result['itinerary'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> enrichedItinerary = [];
      for (int i = 0; i < itinerary.length; i++) {
        final date = departDay.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final weather = _weatherService.getWeatherForDate(weatherData, dateStr);

        enrichedItinerary.add({
          ...itinerary[i],
          'date': dateStr,
          'weather': weather ?? 'No data',
        });
      }

      final userId = FirebaseAuth.instance.currentUser!.uid;

      final trip = {
        'userId': userId,
        'location': location,
        'departDay': departDateStr,
        'returnDay': returnDateStr,
        'departTime': departTimeStr,
        'returnTime': returnTimeStr,
        'totalDays': totalDays,
        'budget': budget,
        'itinerary': enrichedItinerary,
        'suggestions': result['suggestions'] ?? [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.saveItinerary(trip);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewItineraryDetailScreen(tripDetails: trip, isNewTrip: true),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error generating itinerary: $e', style: TextStyle(color: _white)),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showWeatherReminderDialog(String location, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white, // Consistent with currency converter card
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

  // Input Decoration for consistency
  InputDecoration _buildInputDecoration(String labelText, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: _darkPurple.withOpacity(0.8),
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: _mediumPurple)
          : null,
      filled: true,
      fillColor: _lightBeige.withOpacity(0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _mediumPurple.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _mediumPurple.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _darkPurple,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }


  @override
  void dispose() {
    _locationController.dispose();
    _budgetController.dispose();
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
              Color(0xFFF3E5F5), // Light violet
              Color(0xFFFFF5E6), // Light beige
            ],
          ),
        ),
        child: Column(
          children: [
            // Custom AppBar-like section
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
                  // Removed the back button and its SizedBox
                  // IconButton(
                  //   icon: Icon(Icons.arrow_back, color: _darkPurple),
                  //   onPressed: () {
                  //     Navigator.pop(context);
                  //   },
                  // ),
                  // const SizedBox(width: 8),
                  Text(
                    'Create Itinerary', // Title for generating new itinerary
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
                    // Section for generating new itinerary
                    Text(
                      'Plan Your Adventure',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in the details below to generate a personalized trip plan.',
                      style: TextStyle(
                        fontSize: 16,
                        color: _greyText,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card for "Make an Itinerary" button (to toggle form)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isFormVisible
                              ? [Colors.grey.shade400, Colors.grey.shade300] // Dimmed when form is visible
                              : [_darkPurple, _mediumPurple], // Active gradient
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.2),
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
                              isFormVisible = !isFormVisible;
                              // Optionally clear form when hiding
                              if (!isFormVisible) {
                                _locationController.clear();
                                _budgetController.clear();
                                _departDay = null;
                                _returnDay = null;
                                _departTime = null;
                                _returnTime = null;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isFormVisible ? 'Hide Itinerary Form' : 'Make a New Itinerary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isFormVisible ? _greyText : _white,
                                  ),
                                ),
                                Icon(
                                  isFormVisible ? Icons.keyboard_arrow_up : Icons.add_circle_outline,
                                  color: isFormVisible ? _greyText : _white,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Conditionally display the form
                    if (isFormVisible)
                      Column(
                        children: [
                          // Main Form Card
                          Container(
                            decoration: BoxDecoration(
                              color: _white.withOpacity(0.8), // Card background
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
                                const SizedBox(height: 24),

                                // Departure Date and Time (Grouped)
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
                                                    : DateFormat('yyyy-MM-dd').format(_departDay!)),
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
                                                    : _departTime!.format(context)),
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

                                // Return Date and Time (Grouped)
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
                                                    : DateFormat('yyyy-MM-dd').format(_returnDay!)),
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
                                                    : _returnTime!.format(context)),
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

                                // Generate Itinerary Button
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
                                          backgroundColor: _darkPurple, // Main button background
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
                          const SizedBox(height: 24),
                        ],
                      ),

                    // Section for viewing past itineraries
                    Text(
                      'Your Past Adventures',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Access and manage all your previous trip plans.',
                      style: TextStyle(
                        fontSize: 16,
                        color: _greyText,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card for "View All Past Itineraries" button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFFC86FAE)], // Darker purple to pinkish-purple
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const HistoryScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'View All Past Itineraries',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: _white,
                                      ),
                                    ),
                                    Icon(Icons.history, color: _white, size: 36),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Review, modify, or share your saved trip plans from history.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _offWhite,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Icon(Icons.arrow_forward_ios, color: _offWhite, size: 24),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // Ensure bottom padding
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
}