// lib/screens/view_itinerary_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../services/weather_service.dart';
import '../../services/gemini_service.dart';
import '../../../utils/pdf_export.dart';
import 'modify_trip_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewItineraryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tripDetails; // This will include the 'id' for Firestore operations
  final bool isNewTrip; // To differentiate if it's a newly generated trip or from history

  const ViewItineraryDetailScreen({
    super.key,
    required this.tripDetails,
    this.isNewTrip = false, // Default to false
  });

  @override
  State<ViewItineraryDetailScreen> createState() => _ViewItineraryDetailScreenState();
}

class _ViewItineraryDetailScreenState extends State<ViewItineraryDetailScreen> {
  late Map<String, dynamic> _currentTripDetails;
  late List<Map<String, dynamic>> _currentItinerary;
  late List<String> _currentSuggestions;
  bool _isLoading = false; // For PDF generation/deletion
  bool _isLoadingWeather = false; // For weather loading
  bool _isRegeneratingBudget = false; // For budget regeneration
  Map<String, dynamic> _weatherData = {}; // Store weather data

  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();

  // Color scheme consistent with ItineraryScreen.dart
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5); // Light violet
  final Color _gradientEnd = const Color(0xFFFFF5E6); // Light beige

  @override
  void initState() {
    super.initState();
    _currentTripDetails = Map<String, dynamic>.from(widget.tripDetails);
    _currentItinerary = List<Map<String, dynamic>>.from(_currentTripDetails['itinerary']);
    _currentSuggestions = List<String>.from(_currentTripDetails['suggestions']);
    _loadWeatherData(); // Load weather data when screen initializes

    // Check budget status after screen builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBudgetStatus();
    });
  }

  // Check budget status and show dialog if over budget (only for initial load)
  void _checkBudgetStatus() {
    if (_isOverBudget()) {
      // Small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showBudgetControlDialog();
        }
      });
    }
  }

  // Silent budget status check (no dialog, just update UI)
  void _updateBudgetStatus() {
    setState(() {
      // This will trigger a rebuild and update the budget status card
    });
  }

  // Calculate total cost of current itinerary
  double _calculateTotalCost() {
    double total = 0.0;
    for (var item in _currentItinerary) {
      final costStr = item['estimated_cost']?.toString() ?? '0';
      // Remove 'RM' prefix and any spaces, then parse
      final cleanCost = costStr.replaceAll(RegExp(r'[^\d.]'), '');
      final cost = double.tryParse(cleanCost) ?? 0.0;
      total += cost;
    }
    return total;
  }

  // Check if itinerary is over budget
  bool _isOverBudget() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();
    final isOver = totalCost > budget;

    print('🏦 Budget Check: Budget=$budget, Total=$totalCost, Over=$isOver');

    // Debug: Print each item cost
    for (var item in _currentItinerary) {
      final costStr = item['estimated_cost']?.toString() ?? '0';
      final cleanCost = costStr.replaceAll(RegExp(r'[^\d.]'), '');
      final cost = double.tryParse(cleanCost) ?? 0.0;
      print('   Item: ${item['activity']} - Cost: $costStr -> $cost');
    }

    return isOver;
  }

  // Get budget status message
  String _getBudgetStatusMessage() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();
    final difference = totalCost - budget;

    if (difference > 0) {
      return 'Over budget by RM${difference.toStringAsFixed(2)}';
    } else {
      return 'Within budget (RM${(-difference).toStringAsFixed(2)} remaining)';
    }
  }

  // Show budget control dialog when over budget
  void _showBudgetControlDialog() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();

    print('🏦 Budget Control: Budget=$budget, Total Cost=$totalCost, Over Budget=${_isOverBudget()}');

    showDialog(
      context: context,
      barrierDismissible: false, // Don't allow dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Budget Exceeded!',
                  style: TextStyle(
                    color: _darkPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Your Budget:', style: TextStyle(color: _greyText)),
                          Text('RM${budget.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _darkPurple)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Cost:', style: TextStyle(color: _greyText)),
                          Text('RM${totalCost.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _darkPurple)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Over by:', style: TextStyle(color: Colors.red.shade700)),
                          Text('RM${(totalCost - budget).toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How would you like to proceed?',
                  style: TextStyle(fontSize: 16, color: _greyText, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            // Option 1: Keep itinerary as is (over budget)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showKeepOverBudgetConfirmation();
                },
                icon: Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  'Keep Current Plan (Accept Over-Budget)',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Option 2: Get cheaper alternatives
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _suggestCheaperItinerary();
                },
                icon: Icon(Icons.savings, color: Colors.white),
                label: Text(
                  'Generate Cheaper Alternatives',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Option 3: Keep some expensive, replace others
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showSelectiveReplacementDialog();
                },
                icon: Icon(Icons.tune, color: Colors.white),
                label: Text(
                  'Keep Some, Replace Others',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mediumPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation for keeping over-budget itinerary
  void _showKeepOverBudgetConfirmation() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();
    final overAmount = totalCost - budget;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Confirm Over-Budget',
            style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              Text(
                'Your itinerary will cost RM${totalCost.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkPurple),
              ),
              Text(
                'Budget: RM${budget.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: _greyText),
              ),
              Text(
                'Over by: RM${overAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to proceed with this over-budget itinerary?',
                style: TextStyle(fontSize: 14, color: _greyText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back', style: TextStyle(color: _greyText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Proceeding with over-budget itinerary', style: TextStyle(color: _white)),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: _white,
              ),
              child: const Text('Proceed Anyway'),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to select which activities to keep/replace
  void _showSelectiveReplacementDialog() {
    // Get expensive activities (top 30% by cost)
    final sortedActivities = List<Map<String, dynamic>>.from(_currentItinerary);
    sortedActivities.sort((a, b) {
      final costA = double.tryParse(a['estimated_cost']?.toString()?.replaceAll('RM', '').trim() ?? '0') ?? 0.0;
      final costB = double.tryParse(b['estimated_cost']?.toString()?.replaceAll('RM', '').trim() ?? '0') ?? 0.0;
      return costB.compareTo(costA); // Descending order
    });

    final expensiveCount = (sortedActivities.length * 0.3).ceil();
    final expensiveActivities = sortedActivities.take(expensiveCount).toList();

    // Track which expensive activities to keep
    final Map<int, bool> keepActivity = {};
    for (int i = 0; i < expensiveActivities.length; i++) {
      keepActivity[i] = false; // Default: replace all expensive activities
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                'Select Activities to Keep',
                style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'These are your most expensive activities. Select which ones to keep (others will be replaced with cheaper alternatives):',
                      style: TextStyle(fontSize: 14, color: _greyText),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: expensiveActivities.length,
                        itemBuilder: (context, index) {
                          final activity = expensiveActivities[index];
                          final cost = activity['estimated_cost']?.toString() ?? '0';

                          return CheckboxListTile(
                            activeColor: _mediumPurple,
                            title: Text(
                              activity['activity'] ?? 'Unknown Activity',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${activity['place']} - Cost: RM$cost',
                              style: TextStyle(fontSize: 12, color: _greyText),
                            ),
                            value: keepActivity[index] ?? false,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                keepActivity[index] = value ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: _greyText)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _replaceSelectedActivities(expensiveActivities, keepActivity);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mediumPurple,
                    foregroundColor: _white,
                  ),
                  child: const Text('Replace Others'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Replace selected expensive activities with cheaper alternatives
  Future<void> _replaceSelectedActivities(List<Map<String, dynamic>> expensiveActivities, Map<int, bool> keepActivity) async {
    setState(() {
      _isRegeneratingBudget = true;
    });

    try {
      // Build lists of activities to keep and replace
      final List<String> activitiesToKeep = [];
      final List<String> activitiesToReplace = [];

      for (int i = 0; i < expensiveActivities.length; i++) {
        final activity = expensiveActivities[i];
        final activityName = activity['activity']?.toString() ?? '';

        if (keepActivity[i] == true) {
          activitiesToKeep.add(activityName);
        } else {
          activitiesToReplace.add(activityName);
        }
      }

      // Generate new itinerary with selective replacement
      final result = await _regenerateWithSelectiveReplacement(activitiesToKeep, activitiesToReplace);

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate alternatives: ${result['error']}', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        setState(() {
          _currentItinerary = (result['itinerary'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [];
          _currentSuggestions = (result['suggestions'] as List<dynamic>?)?.map((item) => item as String).toList() ?? [];
        });

        await _saveChangesToFirestore();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Itinerary updated with selective replacements!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating itinerary: $e', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        _isRegeneratingBudget = false;
      });
    }
  }

  // Generate cheaper alternatives for the entire itinerary
  Future<void> _suggestCheaperItinerary() async {
    setState(() {
      _isRegeneratingBudget = true;
    });

    try {
      final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
      final newBudget = budget * 0.8; // Aim for 20% less than original budget

      final result = await _regenerateItineraryForBudget(newBudget);

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate cheaper alternatives: ${result['error']}', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        setState(() {
          _currentItinerary = (result['itinerary'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [];
          _currentSuggestions = (result['suggestions'] as List<dynamic>?)?.map((item) => item as String).toList() ?? [];
        });

        await _saveChangesToFirestore();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cheaper itinerary generated successfully!', style: TextStyle(color: _white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating cheaper itinerary: $e', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        _isRegeneratingBudget = false;
      });
    }
  }

  // Regenerate itinerary for a specific budget
  Future<Map<String, dynamic>> _regenerateItineraryForBudget(double targetBudget) async {
    final location = _currentTripDetails['location'] as String;
    final departDay = _currentTripDetails['departDay'] as String;
    final returnDay = _currentTripDetails['returnDay'] as String;
    final departTime = _currentTripDetails['departTime'] as String;
    final returnTime = _currentTripDetails['returnTime'] as String;
    final totalDays = _currentTripDetails['totalDays'] as int;
    final interests = _currentTripDetails['interests'] as String;

    return await GeminiService.generateItinerary(
      location,
      departDay,
      returnDay,
      departTime,
      returnTime,
      totalDays,
      targetBudget,
      interests,
    );
  }

  // Regenerate itinerary with selective replacement
  Future<Map<String, dynamic>> _regenerateWithSelectiveReplacement(List<String> keepActivities, List<String> replaceActivities) async {
    // This would require a more sophisticated Gemini prompt
    // For now, we'll use the budget regeneration method
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    return await _regenerateItineraryForBudget(budget * 0.9);
  }

  // Load weather data for the destination
  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      final String location = _currentTripDetails['location'] as String;
      final weatherData = await _weatherService.getWeatherForecast(location);

      if (!weatherData.containsKey('error')) {
        setState(() {
          _weatherData = weatherData;
        });
      } else {
        print('Weather error: ${weatherData['error']}');
      }
    } catch (e) {
      print('Error loading weather: $e');
    } finally {
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  // Get weather for a specific date
  Map<String, dynamic>? _getWeatherForDate(String date) {
    if (_weatherData.containsKey('forecast') && _weatherData['forecast']['forecastday'] != null) {
      final List<dynamic> forecastDays = _weatherData['forecast']['forecastday'];

      for (var day in forecastDays) {
        if (day['date'] == date) {
          return day;
        }
      }
    }
    return null;
  }

  // Get weather icon based on condition
  IconData _getWeatherIcon(String condition) {
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('sunny') || lowerCondition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (lowerCondition.contains('cloud')) {
      return Icons.wb_cloudy;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      return Icons.grain;
    } else if (lowerCondition.contains('storm') || lowerCondition.contains('thunder')) {
      return Icons.flash_on;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit;
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return Icons.blur_on;
    }
    return Icons.wb_cloudy; // Default
  }

  // Get weather color based on condition
  Color _getWeatherColor(String condition) {
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('sunny') || lowerCondition.contains('clear')) {
      return Colors.orange;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('storm')) {
      return Colors.blue;
    } else if (lowerCondition.contains('cloud')) {
      return Colors.grey.shade600;
    }
    return _mediumPurple; // Default
  }

  // --- Start of corrected _launchMap function ---
  Future<void> _launchMap(String placeName) async {
    // 1. Encode the placeName to handle spaces and special characters
    final encodedPlaceName = Uri.encodeComponent(placeName);

    // 2. Construct the Google Maps URL with the 'q' (query) parameter
    // This URL tells Google Maps to perform a search for the encoded place name.
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedPlaceName';

    try {
      // Attempt to launch the URL.
      // LaunchMode.externalApplication tries to open it in the native app (e.g., Google Maps app).
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        // Fallback: If the native app cannot be launched, open in the default browser.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map app, opening in browser for $placeName')),
        );
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // Catch any errors that occur during the launching process
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open map for $placeName: $e')),
      );
      print('Error launching map for $placeName: $e'); // Log the error for debugging
    }
  }
  // --- End of corrected _launchMap function ---

  // Helper to group flat itinerary list by day
  Map<String, List<Map<String, dynamic>>> _groupItineraryByDay(List<Map<String, dynamic>> itinerary) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in itinerary) {
      final dayKey = item['day'] as String? ?? 'Unknown Day';
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      // Sort activities within each day by time, if 'time' is available
      final String timeStr = item['time']?.toString().toLowerCase() ?? 'z'; // 'z' for sorting at end
      final String sortKey = timeStr.contains('morning') ? 'a' :
      timeStr.contains('afternoon') ? 'b' :
      timeStr.contains('evening') ? 'c' :
      timeStr.length >= 2 ? timeStr.substring(0,2) : timeStr; // For "9:00 AM" etc.

      grouped[dayKey]!.add({...item, '_sortKey': sortKey}); // Add a temporary sort key
    }

    // Sort activities within each day
    grouped.forEach((key, value) {
      value.sort((a, b) => (a['_sortKey'] as String).compareTo(b['_sortKey'] as String));
    });

    // Sort day keys like "Day 1", "Day 2" numerically
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

  // This function was not used in the original build method, but it was present.
  // It provides local deletion of a day, which needs to be explicitly saved if desired.
  void _deleteItineraryDayLocally(int dayIndex) {
    setState(() {
      _currentItinerary.removeWhere((item) {
        final itemDay = item['day'] as String?;
        return itemDay == 'Day ${dayIndex + 1}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted Day ${dayIndex + 1} from display. Remember to save changes to persist.')),
      );
      // If you want to update Firestore immediately after deleting a day locally:
      // _saveChangesToFirestore();
    });
  }

  Future<void> _navigateToModifyTripScreen() async {
    final Map<String, dynamic>? updatedTrip = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModifyTripScreen(initialTripDetails: _currentTripDetails),
      ),
    );

    if (updatedTrip != null) {
      // Update local state with new data
      setState(() {
        _currentItinerary = (updatedTrip['itinerary'] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _currentSuggestions = (updatedTrip['suggestions'] as List<dynamic>)
            .map((item) => item as String)
            .toList();
        _currentTripDetails = updatedTrip; // Update the stored trip details
      });

      // Immediate budget recalculation after state update
      final newTotal = _calculateTotalCost();
      final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
      final wasOverBudget = newTotal > budget;

      print('🔄 After Modification: Budget=$budget, New Total=$newTotal, Still Over=$wasOverBudget');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasOverBudget
                ? 'Itinerary updated - Still over budget by RM${(newTotal - budget).toStringAsFixed(2)}'
                : 'Itinerary updated - Now within budget!',
          ),
          backgroundColor: wasOverBudget ? Colors.orange : Colors.green,
        ),
      );

      // Save changes to Firestore immediately after modification
      await _saveChangesToFirestore();

      // Only show budget dialog if still over budget after modifications
      if (wasOverBudget) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showBudgetControlDialog();
          }
        });
      }
    }
  }

  Future<void> _saveChangesToFirestore() async {
    if (_currentTripDetails.containsKey('id')) {
      try {
        // Update the trip details with current itinerary and suggestions
        _currentTripDetails['itinerary'] = _currentItinerary;
        _currentTripDetails['suggestions'] = _currentSuggestions;

        await _firestoreService.updateItinerary(
          _currentTripDetails['id'],
          {
            'itinerary': _currentItinerary,
            'suggestions': _currentSuggestions,
            'lastModified': DateTime.now().toIso8601String(),
          },
        );

        // Update budget status after saving
        _updateBudgetStatus();

        print('💾 Saved to Firestore - New total cost: ${_calculateTotalCost()}');

      } catch (e) {
        print('❌ Save error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes to history: $e', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else if (widget.isNewTrip) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New trip was already saved or cannot be re-saved without an ID.', style: TextStyle(color: _white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareItineraryAsPdf() async {
    if (_currentTripDetails.isEmpty || _currentItinerary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No itinerary data to share.', style: TextStyle(color: _white)),
          backgroundColor: _mediumPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pdfBytes = await PdfExport.generatePdf(
        _currentTripDetails['location'] as String,
        _currentTripDetails['departDay'] as String,
        _currentTripDetails['returnDay'] as String,
        (_currentTripDetails['budget'] as num).toDouble(), // Ensure budget is a double
        _currentItinerary,
        _currentSuggestions,
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/itinerary_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open PDF: ${result.message}', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Itinerary PDF generated and opened!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error generating or sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing itinerary: $e', style: TextStyle(color: _white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndDeleteTrip() async {
    final String? docId = _currentTripDetails['id'];
    if (docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete: Trip ID not found.', style: TextStyle(color: _white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white, // Changed from black
          title: Text('Confirm Deletion', style: TextStyle(color: _darkPurple)), // Changed text color
          content: Text(
            'Are you sure you want to permanently delete this trip from your history?',
            style: TextStyle(color: _greyText), // Changed text color
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: _mediumPurple)), // Changed text color
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)), // Kept red for delete action
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _firestoreService.deleteItinerary(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip deleted successfully!', style: TextStyle(color: _white)),
            backgroundColor: _mediumPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop(true); // Signal to previous screen that trip was deleted
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete trip: $e', style: TextStyle(color: _white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Build weather card for each day
  Widget _buildWeatherCard(String date, String dayKey) {
    final weatherForDay = _getWeatherForDate(date);

    if (weatherForDay == null) {
      return Container(); // Don't show weather if not available
    }

    final condition = weatherForDay['day']['condition']['text'];
    final maxTemp = weatherForDay['day']['maxtemp_c'].round();
    final minTemp = weatherForDay['day']['mintemp_c'].round();
    final chanceOfRain = weatherForDay['day']['daily_chance_of_rain'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _getWeatherIcon(condition),
            color: _getWeatherColor(condition),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _darkPurple,
                  ),
                ),
                Text(
                  '$minTemp°C - $maxTemp°C',
                  style: TextStyle(
                    fontSize: 12,
                    color: _greyText,
                  ),
                ),
              ],
            ),
          ),
          if (chanceOfRain > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$chanceOfRain% rain',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build budget status card
  Widget _buildBudgetStatusCard() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();
    final isOverBudget = _isOverBudget();
    final statusMessage = _getBudgetStatusMessage();

    // Debug print for real-time updates
    print('🎯 UI Update - Budget: $budget, Total: $totalCost, Over: $isOverBudget');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverBudget
              ? [Colors.red.shade50, Colors.orange.shade50]
              : [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverBudget ? Colors.orange.shade200 : Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isOverBudget ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: isOverBudget ? Colors.orange : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _darkPurple,
                      ),
                    ),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 15,
                        color: isOverBudget ? Colors.red.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total: RM${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  Text(
                    'Budget: RM${budget.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _greyText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Budget exceeded! Use "Modify" to adjust costs or budget control options will appear.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRegeneratingBudget ? null : _showBudgetControlDialog,
                icon: _isRegeneratingBudget
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.tune, color: Colors.white),
                label: Text(
                  _isRegeneratingBudget ? 'Updating...' : 'Budget Control Options',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.thumb_up, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Great! Your itinerary is within budget.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItinerary = _groupItineraryByDay(_currentItinerary);

    return Scaffold(
      backgroundColor: Colors.transparent, // Set to transparent to allow gradient in body
      appBar: AppBar(
        title: Text(
          'Itinerary for ${_currentTripDetails['location']}',
          style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white, // Match ItineraryScreen app bar
        foregroundColor: _darkPurple, // Icon color
        elevation: 0, // Remove shadow
        bottom: PreferredSize( // Add a thin bottom border for separation
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
        actions: [
          if (_isLoadingWeather)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _darkPurple)) // Use purple for loading indicator
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip Overview',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dates: ${_currentTripDetails['departDay']} to ${_currentTripDetails['returnDay']}',
                style: TextStyle(fontSize: 16, color: _greyText),
              ),
              Text(
                'Budget: RM${(_currentTripDetails['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                style: TextStyle(fontSize: 16, color: _greyText),
              ),
              const SizedBox(height: 20),

              // Budget Status Card
              _buildBudgetStatusCard(),

              const SizedBox(height: 10),

              // Action Buttons: Modify, Share, Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)], // Medium to Dark Purple
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15), // More rounded corners
                        boxShadow: [
                          BoxShadow(
                            color: _mediumPurple.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _navigateToModifyTripScreen,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0), // Consistent padding
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Modify',
                                  style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Adjusted spacing
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], // Green gradient for share
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _shareItineraryAsPdf,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.share, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Share PDF',
                                  style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent], // Red gradient for delete
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmAndDeleteTrip,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_forever, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Itinerary Details Display
              Text(
                'Detailed Plan',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here\'s your day-by-day breakdown with weather forecasts, activities and estimated costs.',
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText,
                ),
              ),
              const SizedBox(height: 20),

              if (groupedItinerary.isNotEmpty)
                ...groupedItinerary.entries.map((entry) {
                  final dayKey = entry.key;
                  final dayItems = entry.value;

                  // Extract date for weather lookup
                  String? dayDate;
                  if (dayItems.isNotEmpty && dayItems.first['date'] != null) {
                    dayDate = dayItems.first['date'];
                  } else {
                    // Try to calculate date from departure date and day number
                    try {
                      final departDate = DateFormat('yyyy-MM-dd').parse(_currentTripDetails['departDay']);
                      final dayNum = int.tryParse(dayKey.replaceAll('Day ', '')) ?? 1;
                      final calculatedDate = departDate.add(Duration(days: dayNum - 1));
                      dayDate = DateFormat('yyyy-MM-dd').format(calculatedDate);
                    } catch (e) {
                      print('Error calculating date for $dayKey: $e');
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Consistent card rounding
                    ),
                    elevation: 5, // Consistent shadow
                    shadowColor: _mediumPurple.withOpacity(0.2), // Consistent shadow color
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_lightPurple, _offWhite], // Lighter gradient for daily cards
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Adjusted padding
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayKey,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: _darkPurple, // Dark purple for day title
                              ),
                            ),
                            if (dayDate != null)
                              Text(
                                DateFormat('EEEE, MMM d').format(DateFormat('yyyy-MM-dd').parse(dayDate)),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _greyText,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        iconColor: _darkPurple, // Dark purple for expand icon
                        children: [
                          // Weather info for the day
                          if (dayDate != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: _buildWeatherCard(dayDate, dayKey),
                            ),

                          // Activities for the day
                          ...dayItems.map<Widget>((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${item['time'] ?? 'N/A'}: ${item['place']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: _darkPurple, // Dark purple for time and place
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "🎯 Activity: ${item['activity']}",
                                    style: TextStyle(fontSize: 14, color: _greyText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "⏱️ Duration: ${item['estimated_duration']}",
                                    style: TextStyle(fontSize: 14, color: _greyText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "💲 Cost: RM ${item['estimated_cost']}",
                                    style: TextStyle(fontSize: 14, color: _greyText),
                                  ),
                                  TextButton(
                                    onPressed: () => _launchMap(item['place']),
                                    child: Text(
                                      'View on Map',
                                      style: TextStyle(color: _mediumPurple, fontSize: 14),
                                    ),
                                  ),
                                  const Divider(color: Colors.grey, thickness: 0.2, height: 20), // Separator
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                }).toList(),

              // Suggestions List
              if (_currentSuggestions.isNotEmpty)
                const SizedBox(height: 20),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: _mediumPurple.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_lightPurple, _offWhite], // Lighter gradient for suggestions card
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0), // Increased padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Travel Tips 📒",
                          style: TextStyle(
                            fontSize: 22, // Slightly larger font for header
                            fontWeight: FontWeight.bold,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._currentSuggestions.map((suggestion) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lightbulb_outline, color: _mediumPurple, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: TextStyle(fontSize: 15, color: _greyText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ).toList(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40), // More space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}