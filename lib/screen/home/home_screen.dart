// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../network/gemini_service.dart';
import '../../network/weather_service.dart';
import '../../network/firestore_service.dart'; // Import FirestoreService
import '../history_screen.dart';
import '../view_itinerary_detail_screen.dart'; // New import for detail screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  DateTime? _departDay;
  DateTime? _returnDay;
  TimeOfDay? _departTime;
  TimeOfDay? _returnTime;

  bool isFormVisible = false;
  bool isLoading = false;
  // Removed _itineraryFuture, _currentItinerary, _currentSuggestions, _currentTripDetails from here
  // as the display logic moves to ViewItineraryDetailScreen

  final WeatherService _weatherService = WeatherService();
  final FirestoreService _firestoreService = FirestoreService(); // Initialize Firestore service

  bool get _isFormFilled {
    return _locationController.text.isNotEmpty &&
        _budgetController.text.isNotEmpty &&
        double.tryParse(_budgetController.text) != null &&
        _departDay != null &&
        _returnDay != null &&
        _departTime != null &&
        _returnTime != null;
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0084FF),
              onPrimary: Colors.white,
              surface: Colors.black87,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC86FAE),
              onPrimary: Colors.white,
              surface: Colors.black87,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly (Location, Budget, Departure Date/Time, Return Date/Time).')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String location = _locationController.text;
    final DateTime departDay = _departDay!;
    final DateTime returnDay = _returnDay!;

    // Weather Check
    try {
      final weatherData = await _weatherService.getWeatherForecast(location);
      if (weatherData.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Weather check encountered an error: ${weatherData['error']}. Proceeding with itinerary generation.')),
        );
        _showWeatherReminderDialog(location, "Weather data could not be fetched due to an error. Proceeding with itinerary generation. Please verify weather conditions independently.");
      } else {
        if (_weatherService.hasBadWeather(weatherData)) {
          final weatherDescription = _weatherService.getWeatherDescriptionForDateRange(weatherData, departDay, returnDay);
          _showWeatherReminderDialog(location, "Warning: Bad weather conditions expected during your trip ($weatherDescription). Consider adjusting your plans.");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Good weather expected for your trip to $location!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check weather due to a network error: $e. Proceeding with itinerary generation.')),
      );
      _showWeatherReminderDialog(location, "Weather data could not be fetched due to a network error. Proceeding with itinerary generation. Please verify weather conditions independently.");
    }

    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');

    final String departDayStr = dateFormatter.format(departDay);
    final String returnDayStr = dateFormatter.format(returnDay);
    final String departTimeStr = _departTime!.format(context);
    final String returnTimeStr = _returnTime!.format(context);

    final int daysBetween = returnDay.difference(departDay).inDays + 1;

    try {
      final result = await GeminiService.generateItinerary(
        location,
        departDayStr,
        returnDayStr,
        departTimeStr,
        returnTimeStr,
        daysBetween,
        double.parse(_budgetController.text),
      );

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'].toString())),
        );
        debugPrint('Gemini API Error: ${result['error']}');
      } else {
        // Prepare the trip details to be saved and passed
        final Map<String, dynamic> generatedTripDetails = {
          'location': location,
          'departDay': departDayStr,
          'returnDay': returnDayStr,
          'departTime': departTimeStr,
          'returnTime': returnTimeStr,
          'totalDays': daysBetween,
          'budget': double.parse(_budgetController.text),
          'itinerary': (result['itinerary'] as List<dynamic>?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ??
              [],
          'suggestions': (result['suggestions'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
              [],
          'createdAt': FieldValue.serverTimestamp(), // Add timestamp for history
        };

        // Save the newly generated itinerary to Firestore
        await _firestoreService.saveItinerary(generatedTripDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Itinerary generated and saved to history!')),
        );

        // Navigate to the detail view, indicating it's a new trip for initial save logic in detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewItineraryDetailScreen(tripDetails: generatedTripDetails, isNewTrip: true),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating itinerary: $e')),
      );
      debugPrint('Error generating itinerary: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showWeatherReminderDialog(String location, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text('Weather Alert for $location', style: TextStyle(color: Colors.white)),
          content: Text(message, style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: const Text('OK', style: TextStyle(color: Color(0xFFC86FAE))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // These functions are now handled by ViewItineraryDetailScreen
  // void _navigateToModifyTripScreen() { ... }
  // void _shareItineraryAsPdf() { ... }
  // void _deleteItineraryDay(int dayIndex) { ... }
  // Map<String, List<Map<String, dynamic>>> _groupItineraryByDay(List<Map<String, dynamic>> itinerary) { ... }

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
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: const AssetImage('assets/pp2.jpg'),
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint('Error loading image assets/pp2.jpg: $exception');
                    },
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hi, User Name 👋🏼",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("User",
                          style: TextStyle(fontSize: 14, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome to Travel AI 🗺️",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text("Let AI Handle the Planning, You Enjoy the Trip.",
                      style: TextStyle(fontSize: 16, color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Lets go somewhere over the freedom!",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Where we want to go? 🤔",
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => isFormVisible = true),
                          label: const Text('Make an Itinerary', style: TextStyle(color: Colors.white)),
                          icon: const Icon(Icons.auto_awesome, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color.fromARGB(255, 202, 206, 0), Color.fromARGB(255, 7, 108, 0)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const HistoryScreen())),
                          label: const Text('View History', style: TextStyle(color: Colors.white)),
                          icon: const Icon(Icons.history, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isFormVisible) ...[
                const SizedBox(height: 40),
                TextField(
                  controller: _locationController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Enter Location",
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _budgetController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Enter Budget (RM)",
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    prefixIcon: const Icon(Icons.monetization_on, color: Colors.orange),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 2, color: Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(width: 2, color: Colors.white),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Departure Date and Time (Grouped)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: AbsorbPointer(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            controller: TextEditingController(
                                text: _departDay == null
                                    ? ''
                                    : DateFormat('yyyy-MM-dd').format(_departDay!)),
                            decoration: InputDecoration(
                              labelText: "Departure Date",
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              prefixIcon: const Icon(Icons.calendar_today, color: Colors.white),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                              ),
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
                            style: const TextStyle(color: Colors.white),
                            controller: TextEditingController(
                                text: _departTime == null
                                    ? ''
                                    : _departTime!.format(context)),
                            decoration: InputDecoration(
                              labelText: "Departure Time",
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              prefixIcon: const Icon(Icons.access_time, color: Colors.white),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Return Date and Time (Grouped)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: AbsorbPointer(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            controller: TextEditingController(
                                text: _returnDay == null
                                    ? ''
                                    : DateFormat('yyyy-MM-dd').format(_returnDay!)),
                            decoration: InputDecoration(
                              labelText: "Return Date",
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              prefixIcon: const Icon(Icons.calendar_today, color: Colors.white),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                              ),
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
                            style: const TextStyle(color: Colors.white),
                            controller: TextEditingController(
                                text: _returnTime == null
                                    ? ''
                                    : _returnTime!.format(context)),
                            decoration: InputDecoration(
                              labelText: "Return Time",
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              prefixIcon: const Icon(Icons.access_time, color: Colors.white),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Generate Itinerary Button
                AbsorbPointer(
                  absorbing: isLoading || !canGenerate,
                  child: Opacity(
                    opacity: (isLoading || !canGenerate) ? 0.6 : 1.0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _generateItinerary,
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
                          style: TextStyle(color: Colors.white),
                        ),
                        icon: isLoading
                            ? const SizedBox(width: 0)
                            : const Icon(Icons.auto_awesome, color: Colors.white),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // The FutureBuilder and itinerary display logic is now removed from here
                // as the app navigates to ViewItineraryDetailScreen on successful generation.
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20.0),
                    child: Text(
                      "Your generated itinerary will appear in a new screen and be saved to history.",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}