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
  final Map<String, dynamic> tripDetails;
  final bool isNewTrip;

  const ViewItineraryDetailScreen({
    super.key,
    required this.tripDetails,
    this.isNewTrip = false,
  });

  @override
  State<ViewItineraryDetailScreen> createState() => _ViewItineraryDetailScreenState();
}

class _ViewItineraryDetailScreenState extends State<ViewItineraryDetailScreen> {
  late Map<String, dynamic> _currentTripDetails;
  late List<Map<String, dynamic>> _currentItinerary;
  late List<String> _currentSuggestions;
  bool _isLoading = false;
  bool _isLoadingWeather = false;
  bool _isRegeneratingBudget = false;
  Map<String, dynamic> _weatherData = {};

  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();

  // Consistent color scheme
  final Color _white = Colors.white;
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _greyText = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _currentTripDetails = Map<String, dynamic>.from(widget.tripDetails);
    _currentItinerary = List<Map<String, dynamic>>.from(_currentTripDetails['itinerary'] ?? []);
    _currentSuggestions = List<String>.from(_currentTripDetails['suggestions'] ?? []);
    _loadWeatherData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBudgetStatus();
    });
  }

  void _checkBudgetStatus() {
    if (_isOverBudget()) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showBudgetControlDialog();
        }
      });
    }
  }

  double _calculateTotalCost() {
    double total = 0.0;
    for (var item in _currentItinerary) {
      final costStr = item['estimated_cost']?.toString() ?? '0';
      final cleanCost = costStr.replaceAll(RegExp(r'[^\d.]'), '');
      final cost = double.tryParse(cleanCost) ?? 0.0;
      total += cost;
    }
    return total;
  }

  bool _isOverBudget() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();
    return totalCost > budget;
  }

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

  // Improved time parsing and sorting
  int _parseTimeToMinutes(String timeStr) {
    final cleanTime = timeStr.toLowerCase().trim();

    // Handle time periods
    if (cleanTime.contains('morning')) return 360; // 6:00 AM
    if (cleanTime.contains('afternoon')) return 780; // 1:00 PM
    if (cleanTime.contains('evening')) return 1080; // 6:00 PM
    if (cleanTime.contains('night')) return 1260; // 9:00 PM

    // Parse actual time formats (e.g., "9:00 AM", "2:30 PM", "14:30")
    final timeRegex = RegExp(r'(\d{1,2}):?(\d{0,2})\s*(am|pm)?', caseSensitive: false);
    final match = timeRegex.firstMatch(cleanTime);

    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      int minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final period = match.group(3)?.toLowerCase();

      // Convert 12-hour to 24-hour format
      if (period == 'pm' && hours != 12) {
        hours += 12;
      } else if (period == 'am' && hours == 12) {
        hours = 0;
      }

      return hours * 60 + minutes;
    }

    // Fallback: try to extract just numbers
    final numberMatch = RegExp(r'(\d+)').firstMatch(cleanTime);
    if (numberMatch != null) {
      final hour = int.tryParse(numberMatch.group(1) ?? '0') ?? 0;
      if (hour >= 1 && hour <= 12) {
        // Assume AM/PM based on typical travel patterns
        if (hour >= 1 && hour <= 5) return (hour + 12) * 60; // PM
        return hour * 60; // AM
      } else if (hour >= 13 && hour <= 23) {
        return hour * 60; // 24-hour format
      }
    }

    return 0; // Default to midnight if unparseable
  }

  String _formatTime(String timeStr) {
    final timeInMinutes = _parseTimeToMinutes(timeStr);
    final hours = timeInMinutes ~/ 60;
    final minutes = timeInMinutes % 60;

    if (hours == 0 && minutes == 0) {
      return timeStr; // Return original if parsing failed
    }

    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);

    return '${displayHour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  Map<String, List<Map<String, dynamic>>> _groupItineraryByDay(List<Map<String, dynamic>> itinerary) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var item in itinerary) {
      final dayKey = item['day'] as String? ?? 'Unknown Day';
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }

      // Add time sorting value
      final timeStr = item['time']?.toString() ?? '';
      final timeInMinutes = _parseTimeToMinutes(timeStr);

      grouped[dayKey]!.add({
        ...item,
        '_timeInMinutes': timeInMinutes,
      });
    }

    // Sort activities within each day by time
    grouped.forEach((key, value) {
      value.sort((a, b) => (a['_timeInMinutes'] as int).compareTo(b['_timeInMinutes'] as int));
    });

    // Sort days numerically
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

  void _showBudgetControlDialog() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();

    showDialog(
      context: context,
      barrierDismissible: false,
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
                      _buildBudgetRow('Your Budget:', 'RM${budget.toStringAsFixed(2)}', _darkPurple),
                      const SizedBox(height: 8),
                      _buildBudgetRow('Total Cost:', 'RM${totalCost.toStringAsFixed(2)}', _darkPurple),
                      const Divider(),
                      _buildBudgetRow('Over by:', 'RM${(totalCost - budget).toStringAsFixed(2)}', Colors.red.shade700),
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
            _buildBudgetActionButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showKeepOverBudgetConfirmation();
              },
              icon: Icons.check_circle_outline,
              label: 'Keep Current Plan',
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildBudgetActionButton(
              onPressed: () {
                Navigator.of(context).pop();
                _suggestCheaperItinerary();
              },
              icon: Icons.savings,
              label: 'Generate Cheaper Alternatives',
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _buildBudgetActionButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSelectiveReplacementDialog();
              },
              icon: Icons.tune,
              label: 'Keep Some, Replace Others',
              color: _mediumPurple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBudgetRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _greyText)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildBudgetActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

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
                style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
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
                _showSnackBar('Proceeding with over-budget itinerary', Colors.orange);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Proceed Anyway'),
            ),
          ],
        );
      },
    );
  }

  void _showSelectiveReplacementDialog() {
    final sortedActivities = List<Map<String, dynamic>>.from(_currentItinerary);
    sortedActivities.sort((a, b) {
      final costA = double.tryParse(a['estimated_cost']?.toString()?.replaceAll('RM', '').trim() ?? '0') ?? 0.0;
      final costB = double.tryParse(b['estimated_cost']?.toString()?.replaceAll('RM', '').trim() ?? '0') ?? 0.0;
      return costB.compareTo(costA);
    });

    final expensiveCount = (sortedActivities.length * 0.3).ceil();
    final expensiveActivities = sortedActivities.take(expensiveCount).toList();
    final Map<int, bool> keepActivity = {};
    for (int i = 0; i < expensiveActivities.length; i++) {
      keepActivity[i] = false;
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
                      'Select which expensive activities to keep (others will be replaced):',
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
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Future<void> _replaceSelectedActivities(List<Map<String, dynamic>> expensiveActivities, Map<int, bool> keepActivity) async {
    setState(() {
      _isRegeneratingBudget = true;
    });

    try {
      final result = await _regenerateItineraryForBudget((_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0 * 0.9);

      if (result.containsKey('error')) {
        _showSnackBar('Failed to generate alternatives: ${result['error']}', Colors.redAccent);
      } else {
        setState(() {
          _currentItinerary = (result['itinerary'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [];
          _currentSuggestions = (result['suggestions'] as List<dynamic>?)?.map((item) => item as String).toList() ?? [];
        });

        await _saveChangesToFirestore();
        _showSnackBar('Itinerary updated with selective replacements!', _mediumPurple);
      }
    } catch (e) {
      _showSnackBar('Error updating itinerary: $e', Colors.redAccent);
    } finally {
      setState(() {
        _isRegeneratingBudget = false;
      });
    }
  }

  Future<void> _suggestCheaperItinerary() async {
    setState(() {
      _isRegeneratingBudget = true;
    });

    try {
      final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
      final newBudget = budget * 0.8;

      final result = await _regenerateItineraryForBudget(newBudget);

      if (result.containsKey('error')) {
        _showSnackBar('Failed to generate cheaper alternatives: ${result['error']}', Colors.redAccent);
      } else {
        setState(() {
          _currentItinerary = (result['itinerary'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [];
          _currentSuggestions = (result['suggestions'] as List<dynamic>?)?.map((item) => item as String).toList() ?? [];
        });

        await _saveChangesToFirestore();
        _showSnackBar('Cheaper itinerary generated successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error generating cheaper itinerary: $e', Colors.redAccent);
    } finally {
      setState(() {
        _isRegeneratingBudget = false;
      });
    }
  }

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
      }
    } catch (e) {
      print('Error loading weather: $e');
    } finally {
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

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
    return Icons.wb_cloudy;
  }

  Color _getWeatherColor(String condition) {
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('sunny') || lowerCondition.contains('clear')) {
      return Colors.orange;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('storm')) {
      return Colors.blue;
    } else if (lowerCondition.contains('cloud')) {
      return Colors.grey.shade600;
    }
    return _mediumPurple;
  }

  Future<void> _launchMap(String placeName) async {
    final encodedPlaceName = Uri.encodeComponent(placeName);
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedPlaceName';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open map app for $placeName', Colors.orange);
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      _showSnackBar('Failed to open map for $placeName: $e', Colors.redAccent);
    }
  }

  Future<void> _navigateToModifyTripScreen() async {
    final Map<String, dynamic>? updatedTrip = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModifyTripScreen(initialTripDetails: _currentTripDetails),
      ),
    );

    if (updatedTrip != null) {
      setState(() {
        _currentItinerary = (updatedTrip['itinerary'] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _currentSuggestions = (updatedTrip['suggestions'] as List<dynamic>)
            .map((item) => item as String)
            .toList();
        _currentTripDetails = updatedTrip;
      });

      final newTotal = _calculateTotalCost();
      final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
      final wasOverBudget = newTotal > budget;

      _showSnackBar(
        wasOverBudget
            ? 'Itinerary updated - Still over budget by RM${(newTotal - budget).toStringAsFixed(2)}'
            : 'Itinerary updated - Now within budget!',
        wasOverBudget ? Colors.orange : Colors.green,
      );

      await _saveChangesToFirestore();

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
      } catch (e) {
        _showSnackBar('Failed to save changes: $e', Colors.redAccent);
      }
    }
  }

  Future<void> _shareItineraryAsPdf() async {
    if (_currentTripDetails.isEmpty || _currentItinerary.isEmpty) {
      _showSnackBar('No itinerary data to share.', _mediumPurple);
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
        (_currentTripDetails['budget'] as num).toDouble(),
        _currentItinerary,
        _currentSuggestions,
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/itinerary_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _showSnackBar('Failed to open PDF: ${result.message}', Colors.redAccent);
      } else {
        _showSnackBar('Itinerary PDF generated and opened!', _mediumPurple);
      }
    } catch (e) {
      _showSnackBar('Error sharing itinerary: $e', Colors.redAccent);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndDeleteTrip() async {
    final String? docId = _currentTripDetails['id'];
    if (docId == null) {
      _showSnackBar('Cannot delete: Trip ID not found.', Colors.orange);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Confirm Deletion', style: TextStyle(color: _darkPurple)),
          content: Text(
            'Are you sure you want to permanently delete this trip from your history?',
            style: TextStyle(color: _greyText),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: _mediumPurple)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
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
        _showSnackBar('Trip deleted successfully!', _mediumPurple);
        Navigator.of(context).pop(true);
      } catch (e) {
        _showSnackBar('Failed to delete trip: $e', Colors.redAccent);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildWeatherCard(String date, String dayKey) {
    final weatherForDay = _getWeatherForDate(date);

    if (weatherForDay == null) {
      return Container();
    }

    final condition = weatherForDay['day']['condition']['text'];
    final maxTemp = weatherForDay['day']['maxtemp_c'].round();
    final minTemp = weatherForDay['day']['mintemp_c'].round();
    final chanceOfRain = weatherForDay['day']['daily_chance_of_rain'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _getWeatherIcon(condition),
            color: _getWeatherColor(condition),
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _darkPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$minTemp°C - $maxTemp°C',
                  style: TextStyle(
                    fontSize: 14,
                    color: _greyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (chanceOfRain > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '$chanceOfRain%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetStatusCard() {
    final budget = (_currentTripDetails['budget'] as num?)?.toDouble() ?? 0.0;
    final totalCost = _calculateTotalCost();
    final isOverBudget = _isOverBudget();
    final statusMessage = _getBudgetStatusMessage();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverBudget
              ? [Colors.red.shade50, Colors.orange.shade50]
              : [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOverBudget ? Colors.orange.shade200 : Colors.green.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOverBudget ? Colors.orange : Colors.green).withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isOverBudget ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: isOverBudget ? Colors.orange : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
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
                    'RM${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  Text(
                    'of RM${budget.toStringAsFixed(2)}',
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
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isRegeneratingBudget ? null : _showBudgetControlDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isRegeneratingBudget
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.tune, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _isRegeneratingBudget ? 'Updating...' : 'Budget Control Options',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: _white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItinerary = _groupItineraryByDay(_currentItinerary);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Itinerary for ${_currentTripDetails['location']}',
          style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3E5F5), // Light purple
              Color(0xFFFFF5E6), // Light beige
            ],
          ),
        ),
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _darkPurple),
              const SizedBox(height: 16),
              Text(
                'Processing...',
                style: TextStyle(
                  color: _darkPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _mediumPurple.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: _mediumPurple,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Trip to ${_currentTripDetails['location']}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _darkPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lightPurple.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildTripInfoRow(Icons.calendar_today, 'Dates', '${_currentTripDetails['departDay']} to ${_currentTripDetails['returnDay']}'),
                          const SizedBox(height: 8),
                          _buildTripInfoRow(Icons.access_time, 'Times', '${_currentTripDetails['departTime']} - ${_currentTripDetails['returnTime']}'),
                          const SizedBox(height: 8),
                          _buildTripInfoRow(Icons.account_balance_wallet, 'Budget', 'RM${(_currentTripDetails['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'}'),
                          if (_currentTripDetails['totalDays'] != null) ...[
                            const SizedBox(height: 8),
                            _buildTripInfoRow(Icons.event, 'Duration', '${_currentTripDetails['totalDays']} days'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Budget Status Card
              _buildBudgetStatusCard(),

              // Action Buttons Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _mediumPurple.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            onTap: _navigateToModifyTripScreen,
                            icon: Icons.edit,
                            label: 'Modify',
                            colors: [_mediumPurple, _darkPurple],
                            shadowColor: _mediumPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            onTap: _shareItineraryAsPdf,
                            icon: Icons.share,
                            label: 'Share PDF',
                            colors: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                            shadowColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            onTap: _confirmAndDeleteTrip,
                            icon: Icons.delete_forever,
                            label: 'Delete',
                            colors: const [Colors.red, Colors.redAccent],
                            shadowColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Itinerary Details Display
              Text(
                '📅 Detailed Daily Plan',
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
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              if (groupedItinerary.isNotEmpty)
                ...groupedItinerary.entries.map((entry) {
                  final dayKey = entry.key;
                  final dayItems = entry.value;

                  String? dayDate;
                  if (dayItems.isNotEmpty && dayItems.first['date'] != null) {
                    dayDate = dayItems.first['date'];
                  } else {
                    try {
                      final departDate = DateFormat('yyyy-MM-dd').parse(_currentTripDetails['departDay']);
                      final dayNum = int.tryParse(dayKey.replaceAll('Day ', '')) ?? 1;
                      final calculatedDate = departDate.add(Duration(days: dayNum - 1));
                      dayDate = DateFormat('yyyy-MM-dd').format(calculatedDate);
                    } catch (e) {
                      print('Error calculating date for $dayKey: $e');
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _mediumPurple.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        expansionTileTheme: ExpansionTileThemeData(
                          backgroundColor: Colors.transparent,
                          collapsedBackgroundColor: Colors.transparent,
                          iconColor: _darkPurple,
                          collapsedIconColor: _darkPurple,
                        ),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        childrenPadding: const EdgeInsets.all(0),
                        initiallyExpanded: true,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayKey,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: _darkPurple,
                              ),
                            ),
                            if (dayDate != null)
                              Text(
                                DateFormat('EEEE, MMM d').format(DateFormat('yyyy-MM-dd').parse(dayDate)),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _greyText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Weather info for the day
                                if (dayDate != null)
                                  _buildWeatherCard(dayDate, dayKey),

                                // Activities timeline for the day
                                ...dayItems.asMap().entries.map<Widget>((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  final isLast = index == dayItems.length - 1;

                                  return Container(
                                    margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Timeline indicator
                                        Column(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: _mediumPurple,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            if (!isLast)
                                              Container(
                                                width: 2,
                                                height: 60,
                                                color: _mediumPurple.withOpacity(0.3),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        // Activity content
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [_lightPurple.withOpacity(0.3), _lightBeige.withOpacity(0.3)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: _mediumPurple.withOpacity(0.2)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: _mediumPurple,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        _formatTime(item['time'] ?? 'N/A'),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        "${item['place']}",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18,
                                                          color: _darkPurple,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                _buildInfoRow(Icons.local_activity, "Activity", item['activity']),
                                                _buildInfoRow(Icons.access_time, "Duration", item['estimated_duration']),
                                                _buildInfoRow(Icons.attach_money, "Cost", "RM ${item['estimated_cost']}"),
                                                const SizedBox(height: 8),
                                                Align(
                                                  alignment: Alignment.centerRight,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [_mediumPurple, _darkPurple],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () => _launchMap(item['place']),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: const Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.map, color: Colors.white, size: 16),
                                                              SizedBox(width: 4),
                                                              Text(
                                                                'View on Map',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
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
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

              // Suggestions Section
              if (_currentSuggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _mediumPurple.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: _mediumPurple, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            "Travel Tips & Suggestions",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _darkPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _mediumPurple.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: _currentSuggestions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final suggestion = entry.value;
                            final isLast = index == _currentSuggestions.length - 1;

                            return Container(
                              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _mediumPurple,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _greyText,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Empty state message if no itinerary
              if (groupedItinerary.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _mediumPurple.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: _greyText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Itinerary Available',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _darkPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'There are no activities in this itinerary. Try modifying the trip to add activities.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: _greyText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _mediumPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 16, color: _greyText, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 16, color: _darkPurple, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required List<Color> colors,
    required Color shadowColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: _white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: _mediumPurple, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: _greyText,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontSize: 14,
                color: _darkPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}