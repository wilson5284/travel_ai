// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../network/gemini_service.dart';
import '../history_screen.dart'; // Ensure this path is correct

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // New date and time variables
  DateTime? _departDay;
  DateTime? _returnDay;
  TimeOfDay? _departTime;
  TimeOfDay? _returnTime;

  bool isFormVisible = false;
  bool isLoading = false;
  Future<Map<String, dynamic>>? _itineraryFuture;

  // Stores the generated itinerary for modification
  List<Map<String, dynamic>> _currentItinerary = [];
  List<String> _currentSuggestions = [];

  // Helper to check if form is filled
  bool get _isFormFilled {
    return _locationController.text.isNotEmpty &&
        _budgetController.text.isNotEmpty &&
        double.tryParse(_budgetController.text) != null &&
        _departDay != null &&
        _returnDay != null &&
        _departTime != null &&
        _returnTime != null;
  }

  // --- Date and Time Picker Functions ---
  Future<void> _selectDate(BuildContext context, bool isDepartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0084FF), // Primary color for selected date
              onPrimary: Colors.white,
              surface: Colors.black87, // Background of the picker
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDepartDate) {
          _departDay = picked;
          // Ensure return date is not before depart date
          if (_returnDay != null && _returnDay!.isBefore(_departDay!)) {
            _returnDay = _departDay;
          }
        } else {
          _returnDay = picked;
          // Ensure return date is not before depart date
          if (_departDay != null && _returnDay!.isBefore(_departDay!)) {
            _departDay = _returnDay;
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isDepartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC86FAE), // Primary color for selected time
              onPrimary: Colors.white,
              surface: Colors.black87, // Background of the picker
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDepartTime) {
          _departTime = picked;
        } else {
          _returnTime = picked;
        }
      });
    }
  }

  // --- Generate Itinerary Function ---
  void _generateItinerary() {
    if (!_isFormFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly (Location, Budget, Departure Date/Time, Return Date/Time).')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      _currentItinerary = []; // Clear previous itinerary
      _currentSuggestions = []; // Clear previous suggestions

      final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
      // Time will be formatted by TimeOfDay.format(context) for locale consistency

      final String departDayStr = dateFormatter.format(_departDay!);
      final String returnDayStr = dateFormatter.format(_returnDay!);
      final String departTimeStr = _departTime!.format(context);
      final String returnTimeStr = _returnTime!.format(context);

      // Calculate number of days
      final int daysBetween = _returnDay!.difference(_departDay!).inDays + 1;


      _itineraryFuture = GeminiService.generateItinerary(
        _locationController.text,
        departDayStr,
        returnDayStr,
        departTimeStr,
        returnTimeStr,
        daysBetween,
        double.parse(_budgetController.text),
      ).then((result) {
        if (result.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'].toString())),
          );
          debugPrint('Gemini API Error: ${result['error']}');
        } else {
          // Store the generated data for display and future modification
          _currentItinerary = (result['itinerary'] as List<dynamic>?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ??
              [];
          _currentSuggestions = (result['suggestions'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
              [];
        }
        return result;
      }).whenComplete(() => setState(() => isLoading = false));
    });
  }


  void _editItineraryDay(int dayIndex, Map<String, dynamic> dayData) {
    debugPrint('Editing Day ${dayIndex + 1} itinerary: $dayData');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality is not yet implemented!')),
    );
    // For a full implementation, you'd show a form/dialog pre-filled with dayData
    // and allow user to modify/add/remove items for that day.
    // On save, update _currentItinerary and call setState.
  }

  void _deleteItineraryDay(int dayIndex) {
    setState(() {
      _currentItinerary.removeWhere((item) {
        final itemDay = item['day'] as String?;
        return itemDay == 'Day ${dayIndex + 1}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted Day ${dayIndex + 1} itinerary.')),
      );
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupItineraryByDay(List<Map<String, dynamic>> itinerary) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in itinerary) {
      final dayKey = item['day'] as String? ?? 'Unknown Day';
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      grouped[dayKey]!.add(item);
    }
    final sortedKeys = grouped.keys.toList();
    sortedKeys.sort((a, b) {
      final aNum = int.tryParse(a.replaceAll('Day ', '')) ?? 0;
      final bNum = int.tryParse(b.replaceAll('Day ', '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    final sortedGrouped = <String, List<Map<String, dynamic>>>{};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    return sortedGrouped;
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
    final groupedItinerary = _groupItineraryByDay(_currentItinerary);

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
                      Text("Hi, Panjoel 👋🏼",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("Travel Enthusiast",
                          style: TextStyle(fontSize: 14, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome to Travel AI🗺️",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text("Lets AI Handle the Planning, You Enjoy the Trip.",
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
                        "Lets go somewhere over freedom!",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Where we go?🤔",
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
                // Departure Date Selection
                GestureDetector(
                  onTap: () => _selectDate(context, true),
                  child: AbsorbPointer( // Prevents direct text input
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(
                          text: _departDay == null
                              ? ''
                              : DateFormat('yyyy-MM-dd').format(_departDay!)),
                      decoration: InputDecoration(
                        labelText: "Select Departure Date",
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
                const SizedBox(height: 12),
                // Return Date Selection
                GestureDetector(
                  onTap: () => _selectDate(context, false),
                  child: AbsorbPointer(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(
                          text: _returnDay == null
                              ? ''
                              : DateFormat('yyyy-MM-dd').format(_returnDay!)),
                      decoration: InputDecoration(
                        labelText: "Select Return Date",
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
                const SizedBox(height: 12),
                // Departure Time Selection
                GestureDetector(
                  onTap: () => _selectTime(context, true),
                  child: AbsorbPointer(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(
                          text: _departTime == null
                              ? ''
                              : _departTime!.format(context)),
                      decoration: InputDecoration(
                        labelText: "Select Departure Time",
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
                const SizedBox(height: 12),
                // Return Time Selection
                GestureDetector(
                  onTap: () => _selectTime(context, false),
                  child: AbsorbPointer(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(
                          text: _returnTime == null
                              ? ''
                              : _returnTime!.format(context)),
                      decoration: InputDecoration(
                        labelText: "Select Return Time",
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
                const SizedBox(height: 24),
                // Generate Itinerary Button
                AbsorbPointer(
                  absorbing: isLoading || !canGenerate,
                  child: Opacity(
                    opacity: (isLoading || !canGenerate) ? 0.6 : 1.0,
                    child: Container(
                      width: double.infinity, // Make button fill width
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
                // FutureBuilder to display AI-generated itinerary
                // Once the response arrives, data is stored in _currentItinerary and _currentSuggestions
                // This allows for direct manipulation of these lists for itinerary modification.
                FutureBuilder<Map<String, dynamic>>(
                  future: _itineraryFuture,
                  builder: (context, snapshot) {
                    if (isLoading && _itineraryFuture == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.connectionState == ConnectionState.waiting && _itineraryFuture != null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                    }
                    if (!snapshot.hasData || snapshot.data == null || (_currentItinerary.isEmpty && _currentSuggestions.isEmpty)) {
                      return const Center(
                        child: Text(
                          "You haven't generated any itinerary yet 🗿",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (snapshot.data!.containsKey('error')) {
                      return Center(
                        child: Text(
                          snapshot.data!['error'].toString(),
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // Display itinerary and suggestions
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display itinerary grouped by day
                        if (groupedItinerary.isNotEmpty)
                          ...groupedItinerary.entries.map((entry) {
                            final dayKey = entry.key; // e.g., "Day 1"
                            final dayItems = entry.value;

                            // Calculate day index for delete/edit (e.g., extract 1 from "Day 1", then subtract 1 for index 0)
                            final dayIndex = int.tryParse(dayKey.replaceAll('Day ', '')) != null
                                ? int.parse(dayKey.replaceAll('Day ', '')) - 1
                                : -1;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ExpansionTile( // Use ExpansionTile to collapse/expand each day's itinerary
                                  title: Text(
                                    dayKey, // e.g., "Day 1"
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white),
                                        onPressed: () {
                                          // When the "Edit" button for a day is clicked
                                          // You might need to pass all itinerary items for that day
                                          _editItineraryDay(dayIndex, {'day': dayKey, 'items': dayItems});
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () {
                                          _deleteItineraryDay(dayIndex);
                                        },
                                      ),
                                    ],
                                  ),
                                  children: dayItems.map<Widget>((item) {
                                    return ListTile(
                                      title: Text(
                                        "${item['place']} (${item['time'] ?? 'N/A'})",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            "🎯 Activity : ${item['activity']}",
                                            style: const TextStyle(fontSize: 14, color: Colors.white),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "⏱️ Duration : ${item['estimated_duration']}",
                                            style: const TextStyle(fontSize: 14, color: Colors.white),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "💲 Cost : RM ${item['estimated_cost']}",
                                            style: const TextStyle(fontSize: 14, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          }).toList(),

                        // Suggestions List
                        if (_currentSuggestions.isNotEmpty)
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFC86FAE), Color(0xFF0084FF)],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Tips 📒",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    ..._currentSuggestions.map((suggestion) => Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        "💡 $suggestion",
                                        style: const TextStyle(fontSize: 14, color: Colors.white),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}