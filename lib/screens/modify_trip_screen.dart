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

  // Helper to get a unique key for each activity item for controllers
  // This is crucial for dynamically added/removed fields
  Key _getKeyForActivity(int dayIndex, int activityIndex) {
    // Generate a unique key based on day and activity index
    return ValueKey('day_${dayIndex}_activity_${activityIndex}');
  }

  // Group itinerary items by day for display and modification
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
      // Sort to keep new activities at the end of their day or by time if specified
      _editableItinerary.sort((a, b) {
        final aDayNum = int.tryParse((a['day'] as String).replaceAll('Day ', '')) ?? 0;
        final bDayNum = int.tryParse((b['day'] as String).replaceAll('Day ', '')) ?? 0;

        if (aDayNum != bDayNum) {
          return aDayNum.compareTo(bDayNum);
        }

        // Secondary sort by time if days are the same
        final aTime = (a['time'] as String?)?.toLowerCase() ?? '';
        final bTime = (b['time'] as String?)?.toLowerCase() ?? '';

        if (aTime.contains('morning') && !bTime.contains('morning')) return -1;
        if (!aTime.contains('morning') && bTime.contains('morning')) return 1;
        if (aTime.contains('afternoon') && !bTime.contains('afternoon')) return -1;
        if (!aTime.contains('afternoon') && bTime.contains('afternoon')) return 1;
        if (aTime.contains('evening') && !bTime.contains('evening')) return -1;
        if (!aTime.contains('evening') && bTime.contains('evening')) return 1;

        return aTime.compareTo(bTime); // Fallback for specific times or general comparison
      });
    });
  }


  void _removeActivity(String dayKey, int activityIndex) {
    setState(() {
      final List<Map<String, dynamic>> activitiesForDay = _editableItinerary
          .where((item) => item['day'] == dayKey)
          .toList();

      if (activityIndex < activitiesForDay.length) {
        final Map<String, dynamic> activityToRemove = activitiesForDay[activityIndex];
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

  @override
  Widget build(BuildContext context) {
    final groupedItinerary = _groupItineraryByDay(_editableItinerary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Trip', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Modify Itinerary",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Iterate through grouped itinerary days
            ...groupedItinerary.entries.map((entry) {
              final dayKey = entry.key;
              final dayActivities = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                color: Colors.grey[900], // Dark background for card
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF0084FF)),
                            onPressed: () => _addActivity(dayKey),
                            tooltip: 'Add Activity to this Day',
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      // Iterate through activities for each day
                      ...dayActivities.asMap().entries.map((activityEntry) {
                        final int activityIndexInDay = activityEntry.key;
                        final Map<String, dynamic> activity = activityEntry.value;

                        // Find the original index in the _editableItinerary list
                        // This is crucial because dayActivities is a filtered list
                        final int originalIndex = _editableItinerary.indexOf(activity);


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
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                    onPressed: () => _removeActivity(dayKey, activityIndexInDay),
                                    tooltip: 'Remove this Activity',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: _getKeyForActivity(originalIndex, 0), // Unique key
                                controller: TextEditingController(text: activity['place']),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Place',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.place, color: Colors.white),
                                ),
                                onChanged: (value) {
                                  _editableItinerary[originalIndex]['place'] = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: _getKeyForActivity(originalIndex, 1),
                                controller: TextEditingController(text: activity['time']),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Time',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time, color: Colors.white),
                                ),
                                onChanged: (value) {
                                  _editableItinerary[originalIndex]['time'] = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: _getKeyForActivity(originalIndex, 2),
                                controller: TextEditingController(text: activity['activity']),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Activity',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.local_activity, color: Colors.white),
                                ),
                                onChanged: (value) {
                                  _editableItinerary[originalIndex]['activity'] = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: _getKeyForActivity(originalIndex, 3),
                                controller: TextEditingController(text: activity['estimated_duration']),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Duration',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.hourglass_empty, color: Colors.white),
                                ),
                                onChanged: (value) {
                                  _editableItinerary[originalIndex]['estimated_duration'] = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: _getKeyForActivity(originalIndex, 4),
                                controller: TextEditingController(text: activity['estimated_cost']),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Cost (RM)',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.attach_money, color: Colors.white),
                                ),
                                onChanged: (value) {
                                  _editableItinerary[originalIndex]['estimated_cost'] = value;
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 20),
            const Text(
              "Modify Suggestions",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Iterate through suggestions
            ..._editableSuggestions.asMap().entries.map((entry) {
              final int index = entry.key;
              final String suggestion = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('suggestion_$index'), // Unique key for suggestion
                        controller: TextEditingController(text: suggestion),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Suggestion ${index + 1}',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lightbulb_outline, color: Colors.white),
                        ),
                        onChanged: (value) {
                          _editableSuggestions[index] = value;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                      onPressed: () => _removeSuggestion(index),
                      tooltip: 'Remove this Suggestion',
                    ),
                  ],
                ),
              );
            }).toList(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addSuggestion,
                icon: const Icon(Icons.add, color: Color(0xFF0084FF)),
                label: const Text('Add Suggestion', style: TextStyle(color: Color(0xFF0084FF))),
              ),
            ),
            const SizedBox(height: 30),
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
                onPressed: _saveChanges,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save Changes', style: TextStyle(color: Colors.white)),
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
    );
  }
}
