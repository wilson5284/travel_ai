// lib/screens/modify_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModifyTripScreen extends StatefulWidget {
  final Map<String, dynamic> initialTripDetails;

  const ModifyTripScreen({super.key, required this.initialTripDetails});

  @override
  State<ModifyTripScreen> createState() => _ModifyTripScreenState();
}

class _ModifyTripScreenState extends State<ModifyTripScreen> {
  // Use a temporary list to hold editable itinerary items
  late List<Map<String, dynamic>> _editableItinerary;
  late List<String> _editableSuggestions;

  // Color scheme consistent across the app
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  @override
  void initState() {
    super.initState();
    // Deep copy the initial itinerary and suggestions to allow local modifications
    _editableItinerary = (widget.initialTripDetails['itinerary'] as List<dynamic>?)
        ?.map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList() ??
        [];
    _editableSuggestions = List<String>.from(widget.initialTripDetails['suggestions'] ?? []);
  }

  // Helper to group flat itinerary list by day
  Map<String, List<Map<String, dynamic>>> _groupItineraryByDay(List<Map<String, dynamic>> itinerary) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in itinerary) {
      final dayKey = item['day'] as String? ?? 'Unknown Day';
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      // Add a temporary sort key to preserve original order or apply a logical one
      final String timeStr = item['time']?.toString().toLowerCase() ?? 'z';
      final String sortKey = timeStr.contains('morning') ? 'a' :
      timeStr.contains('afternoon') ? 'b' :
      timeStr.contains('evening') ? 'c' :
      timeStr.substring(0,2) ;

      grouped[dayKey]!.add({...item, '_sortKey': sortKey});
    }

    // Sort activities within each day
    grouped.forEach((key, value) {
      value.sort((a, b) => (a['_sortKey'] as String).compareTo(b['_sortKey'] as String));
    });

    // Sort day keys numerically
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

  void _addActivity(String dayKey) {
    setState(() {
      _editableItinerary.add({
        'day': dayKey,
        'place': '',
        'time': '',
        'activity': '',
        'estimated_duration': '',
        'estimated_cost': '',
      });
      // Re-group and re-sort to ensure new activity appears correctly
      // (This will re-calculate _groupItineraryByDay on build)
    });
  }


  void _removeActivity(String dayKey, int activityIndexInDay) {
    setState(() {
      // Create a copy of the list of activities for the specific day to avoid modifying
      // the list while iterating or trying to find an index in a sub-list.
      final List<Map<String, dynamic>> activitiesForDay = _editableItinerary
          .where((item) => item['day'] == dayKey)
          .toList();

      if (activityIndexInDay < activitiesForDay.length) {
        final Map<String, dynamic> activityToRemove = activitiesForDay[activityIndexInDay];
        _editableItinerary.remove(activityToRemove);
      }
    });
  }

  void _addSuggestion() {
    setState(() {
      _editableSuggestions.add(''); // Add a new empty suggestion
    });
  }

  void _removeSuggestion(int index) {
    setState(() {
      _editableSuggestions.removeAt(index);
    });
  }

  void _saveChanges() {
    // Reconstruct the updated trip details map
    final Map<String, dynamic> updatedTripDetails = Map.from(widget.initialTripDetails);
    updatedTripDetails['itinerary'] = _editableItinerary;
    updatedTripDetails['suggestions'] = _editableSuggestions;
    // Add a timestamp for when it was last modified
    updatedTripDetails['lastModified'] = FieldValue.serverTimestamp();

    Navigator.pop(context, updatedTripDetails); // Pass updated data back
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
  Widget build(BuildContext context) {
    final groupedItinerary = _groupItineraryByDay(_editableItinerary);

    return Scaffold(
      backgroundColor: Colors.transparent, // Set to transparent for gradient
      appBar: AppBar(
        title: Text('Modify Trip', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        backgroundColor: _white, // Consistent app bar background
        foregroundColor: _darkPurple, // Consistent icon color
        elevation: 0, // Remove shadow
        bottom: PreferredSize( // Add a thin bottom border for separation
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Customize Your Plan",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Make changes to your itinerary and suggestions below.",
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText,
                ),
              ),
              const SizedBox(height: 30),

              // Modify Itinerary Section
              Text(
                "Modify Itinerary",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 16),
              // Iterate through grouped itinerary days
              ...groupedItinerary.entries.map((entry) {
                final dayKey = entry.key;
                final dayActivities = entry.value;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // Consistent card rounding
                  ),
                  elevation: 5, // Consistent shadow
                  shadowColor: _mediumPurple.withOpacity(0.2), // Consistent shadow color
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_offWhite, _lightPurple], // Lighter gradient for daily cards
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dayKey,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _darkPurple,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _mediumPurple, // Background for add button
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.add, color: _white), // White icon
                                  onPressed: () => _addActivity(dayKey),
                                  tooltip: 'Add Activity to this Day',
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey, thickness: 0.2, height: 20), // Separator
                          // Iterate through activities for each day
                          ...dayActivities.asMap().entries.map((activityEntry) {
                            final int activityIndexInDay = activityEntry.key;
                            final Map<String, dynamic> activity = activityEntry.value;

                            // Find the original index in the _editableItinerary list
                            // This is crucial because dayActivities is a filtered list based on the day.
                            // We need the actual index in the flat _editableItinerary list to update it.
                            final int originalIndex = _editableItinerary.indexWhere(
                                  (element) =>
                              element['day'] == dayKey &&
                                  element['place'] == activity['place'] &&
                                  element['time'] == activity['time'] &&
                                  element['activity'] == activity['activity'],
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Activity ${activityIndexInDay + 1}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _greyText,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.redAccent, // Background for remove button
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.remove, color: _white), // White icon
                                          onPressed: () => _removeActivity(dayKey, activityIndexInDay),
                                          tooltip: 'Remove this Activity',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // TextFields using the new InputDecoration
                                  TextField(
                                    controller: TextEditingController(text: activity['place']),
                                    style: TextStyle(color: _darkPurple),
                                    decoration: _buildInputDecoration('Place', prefixIcon: Icons.place),
                                    onChanged: (value) {
                                      if (originalIndex != -1) _editableItinerary[originalIndex]['place'] = value;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(text: activity['time']),
                                    style: TextStyle(color: _darkPurple),
                                    decoration: _buildInputDecoration('Time', prefixIcon: Icons.access_time),
                                    onChanged: (value) {
                                      if (originalIndex != -1) _editableItinerary[originalIndex]['time'] = value;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(text: activity['activity']),
                                    style: TextStyle(color: _darkPurple),
                                    decoration: _buildInputDecoration('Activity', prefixIcon: Icons.local_activity),
                                    onChanged: (value) {
                                      if (originalIndex != -1) _editableItinerary[originalIndex]['activity'] = value;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(text: activity['estimated_duration']),
                                    style: TextStyle(color: _darkPurple),
                                    decoration: _buildInputDecoration('Duration', prefixIcon: Icons.hourglass_empty),
                                    onChanged: (value) {
                                      if (originalIndex != -1) _editableItinerary[originalIndex]['estimated_duration'] = value;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(text: activity['estimated_cost']),
                                    style: TextStyle(color: _darkPurple),
                                    keyboardType: TextInputType.number,
                                    decoration: _buildInputDecoration('Cost (RM)', prefixIcon: Icons.attach_money),
                                    onChanged: (value) {
                                      if (originalIndex != -1) _editableItinerary[originalIndex]['estimated_cost'] = value;
                                    },
                                  ),
                                  if (activityIndexInDay < dayActivities.length -1 )
                                    const Padding(
                                      padding: EdgeInsets.only(top: 16.0),
                                      child: Divider(color: Colors.grey, thickness: 0.2, height: 0),
                                    )
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 30),

              // Modify Suggestions Section
              Text(
                "Modify Suggestions",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: _mediumPurple.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_offWhite, _lightPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._editableSuggestions.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final String suggestion = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: suggestion),
                                    style: TextStyle(color: _darkPurple),
                                    decoration: _buildInputDecoration(
                                      'Suggestion ${index + 1}',
                                      prefixIcon: Icons.lightbulb_outline,
                                    ),
                                    onChanged: (value) {
                                      _editableSuggestions[index] = value;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.redAccent,
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.remove, color: _white),
                                    onPressed: () => _removeSuggestion(index),
                                    tooltip: 'Remove this Suggestion',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addSuggestion,
                            icon: Icon(Icons.add_circle, color: _mediumPurple, size: 28), // Larger icon
                            label: Text(
                              'Add New Suggestion',
                              style: TextStyle(color: _mediumPurple, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Save Changes Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)], // Medium to Dark Purple
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15), // Consistent button rounding
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
                    onTap: _saveChanges,
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0), // Consistent padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: _white, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Save Changes',
                            style: TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 18),
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
    );
  }
}