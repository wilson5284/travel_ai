// lib/screens/home/insurance_suggestion_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class InsuranceSuggestionScreen extends StatefulWidget {
  const InsuranceSuggestionScreen({super.key});

  @override
  State<InsuranceSuggestionScreen> createState() => _InsuranceSuggestionScreenState();
}

class _InsuranceSuggestionScreenState extends State<InsuranceSuggestionScreen> {
  // Define color scheme consistent with ItineraryScreen
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _white = Colors.white;
  final Color _greyText = Colors.grey.shade600;

  // Text Editing Controllers for input fields
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _tripStartDateController = TextEditingController();
  final TextEditingController _tripEndDateController = TextEditingController();
  final TextEditingController _numTravelersController = TextEditingController();
  final TextEditingController _activitiesController = TextEditingController();

  List<Map<String, String>> _suggestions = []; // List of maps to keep icon/color logic
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _destinationController.dispose();
    _tripStartDateController.dispose();
    _tripEndDateController.dispose();
    _numTravelersController.dispose();
    _activitiesController.dispose();
    super.dispose();
  }

  // Placeholder for generating insurance suggestions
  Future<void> _generateInsuranceSuggestions() async {
    setState(() {
      _isLoading = true;
      _suggestions = [];
      _errorMessage = '';
    });

    // Basic validation
    if (_destinationController.text.isEmpty || _tripStartDateController.text.isEmpty || _tripEndDateController.text.isEmpty || _numTravelersController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required trip details.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Simulate API call or complex logic
      await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

      // Example of generating dummy suggestions based on input
      // Removed 'brand_example' key as it's no longer displayed
      final String destination = _destinationController.text;
      // final String startDate = _tripStartDateController.text; // Not directly used in suggestion string
      // final String endDate = _tripEndDateController.text; // Not directly used in suggestion string
      final int numTravelers = int.tryParse(_numTravelersController.text) ?? 1;
      final String activities = _activitiesController.text.toLowerCase();

      List<Map<String, String>> generated = [];

      generated.add({
        'title': 'Comprehensive Travel Plan',
        'description': 'Covers medical emergencies, trip cancellation, and lost luggage for your trip to $destination.',
        'icon': 'health_and_safety',
        'color': '#C86FAE', // Hex color for consistency
      });

      if (numTravelers > 1) {
        generated.add({
          'title': 'Family / Group Coverage',
          'description': 'Specialized plan for $numTravelers travelers, simplifying the process for multiple individuals.',
          'icon': 'people',
          'color': '#6A1B9A', // _darkPurple
        });
      }

      if (activities.contains('skiing') || activities.contains('diving') || activities.contains('hiking')) {
        generated.add({
          'title': 'Adventure Sports Add-on',
          'description': 'Essential for activities like skiing, diving, or extreme hiking to ensure all risks are covered.',
          'icon': 'downhill_skiing',
          'color': '#9C27B0', // _mediumPurple
        });
      } else {
        generated.add({
          'title': 'Standard Activity Coverage',
          'description': 'Covers typical tourist activities. No specific high-risk riders needed.',
          'icon': 'sports_handball',
          'color': '#00B0FF', // A new blue for variety
        });
      }

      generated.add({
        'title': 'Baggage Protection Plus',
        'description': 'Ensures your personal belongings are covered against loss, theft, or delay.',
        'icon': 'luggage',
        'color': '#FFA726', // An orange for variety
      });

      setState(() {
        _suggestions = generated;
        _isLoading = false;
      });
      _showSnackBar('Suggestions generated successfully!', backgroundColor: _mediumPurple);

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate suggestions: ${e.toString()}';
        _isLoading = false;
      });
      _showSnackBar('Error: $_errorMessage', backgroundColor: Colors.red);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Travel Insurance Advisor',
          style: TextStyle(
            color: _darkPurple, // Consistent app bar title color
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _white, // Consistent app bar background
        elevation: 0, // No shadow for app bar
        iconTheme: IconThemeData(color: _darkPurple), // Back button color
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get Insurance Suggestions',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple, // Consistent heading color
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your trip details to get tailored travel insurance advice.',
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText, // Consistent body text color
                ),
              ),
              const SizedBox(height: 32),

              // Trip Details Input Card - Styled like Currency Converter/Itinerary Input
              _buildInputCard(
                children: [
                  _buildTextField(
                    'Destination',
                    'e.g., Paris, Japan',
                    Icons.location_on,
                    controller: _destinationController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Trip Start Date',
                    'Select Date',
                    Icons.calendar_today,
                    readOnly: true,
                    controller: _tripStartDateController,
                    onTap: () => _selectDate(context, _tripStartDateController),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Trip End Date',
                    'Select Date',
                    Icons.calendar_today,
                    readOnly: true,
                    controller: _tripEndDateController,
                    onTap: () => _selectDate(context, _tripEndDateController),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Number of Travelers',
                    'e.g., 2',
                    Icons.people,
                    keyboardType: TextInputType.number,
                    controller: _numTravelersController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Activities (optional)',
                    'e.g., Skiing, Diving',
                    Icons.sports_handball,
                    controller: _activitiesController,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateInsuranceSuggestions, // Disable button while loading
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.shield, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Generating...' : 'Get Advice',
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkPurple, // Consistent button color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 3,
                        shadowColor: _darkPurple.withAlpha((255 * 0.3).round()),
                      ),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 40),

              // Suggestions Output Section
              if (_suggestions.isNotEmpty || _isLoading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Suggestions',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Based on your details, here are some general insurance considerations:',
                      style: TextStyle(
                        fontSize: 16,
                        color: _greyText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_isLoading && _suggestions.isEmpty) // Show loading indicator when fetching suggestions
                      Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_mediumPurple),
                        ),
                      ),

                    if (_suggestions.isNotEmpty)
                      _buildSuggestionCardList(), // Use a separate widget for suggestion list
                  ],
                ),

              if (_suggestions.isNotEmpty || _errorMessage.isNotEmpty) // Only show disclaimer if suggestions were attempted
                Column(
                  children: [
                    const SizedBox(height: 30),
                    _buildDisclaimerCard(), // Add the disclaimer here
                  ],
                ),

              const SizedBox(height: 24), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _white.withAlpha((255 * 0.8).round()), // Consistent card background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withAlpha((255 * 0.1).round()),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSuggestionCardList() {
    return Column(
      children: _suggestions.map((suggestion) {
        // Map string icon/color to actual IconData/Color
        IconData iconData;
        Color displayColor;

        switch (suggestion['icon']) {
          case 'health_and_safety': iconData = Icons.health_and_safety; break;
          case 'people': iconData = Icons.people; break;
          case 'downhill_skiing': iconData = Icons.downhill_skiing; break;
          case 'sports_handball': iconData = Icons.sports_handball; break;
          case 'luggage': iconData = Icons.luggage; break;
          case 'cancel': iconData = Icons.cancel; break; // Added for completeness if needed
          default: iconData = Icons.info_outline; break;
        }

        // Convert hex color string to Color object
        try {
          String hexColor = suggestion['color']!.replaceAll('#', '');
          if (hexColor.length == 6) {
            hexColor = 'FF' + hexColor; // Add alpha for full opacity
          }
          displayColor = Color(int.parse(hexColor, radix: 16));
        } catch (e) {
          displayColor = _mediumPurple; // Fallback color
        }


        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildSuggestionCard(
            title: suggestion['title']!,
            description: suggestion['description']!,
            // brandExample: suggestion['brand_example'], // REMOVED: No longer passing this
            icon: iconData,
            color: displayColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuggestionCard({
    required String title,
    required String description,
    // String? brandExample, // REMOVED: No longer accepting this parameter
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).round()), // Light version of the accent color
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: _greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // REMOVED: The entire Padding widget that displayed brandExample
        ],
      ),
    );
  }

  Widget _buildTextField(
      String labelText,
      String hintText,
      IconData icon, {
        bool readOnly = false,
        VoidCallback? onTap,
        TextInputType keyboardType = TextInputType.text,
        TextEditingController? controller, // Added controller parameter
      }) {
    return TextFormField(
      controller: controller, // Assign controller
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(
          color: _darkPurple.withAlpha((255 * 0.8).round()),
        ),
        hintStyle: TextStyle(
          color: _greyText.withAlpha((255 * 0.6).round()),
        ),
        prefixIcon: Icon(icon, color: _mediumPurple),
        filled: true,
        fillColor: _lightBeige.withAlpha((255 * 0.6).round()),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _mediumPurple.withAlpha((255 * 0.4).round()),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _mediumPurple.withAlpha((255 * 0.4).round()),
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
      ),
      style: TextStyle(
        color: _darkPurple,
        fontSize: 16,
      ),
    );
  }

  // Helper for date picker
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _mediumPurple, // Header background color
              onPrimary: _white, // Header text color
              onSurface: _darkPurple, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _darkPurple, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked); // Format and set the date
      });
      _showSnackBar('Date selected: ${controller.text}');
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? _mediumPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // The critical disclaimer card
  Widget _buildDisclaimerCard() {
    return Card( // Use Card for a distinct, elevated look
      color: Colors.red.shade50, // Very light red background for the card itself
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gpp_bad, color: Colors.red.shade700, size: 28), // Larger, more serious icon
                const SizedBox(width: 10),
                Expanded( // Use Expanded to prevent overflow for long text
                  child: Text(
                    'CRITICAL DISCLAIMER: PLEASE READ IMMEDIATELY', // Even more urgent title
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'The information provided is for **general informational purposes ONLY and '
                  'DO NOT constitute financial, legal, or insurance advice. This application is '
                  'NOT a licensed insurance agent or broker**.\n\nAny examples of coverage types are illustrative; '
                  'they do not represent actual product recommendations or endorsements. Real insurance products, terms, and availability vary.'
                  '\n\n**YOU MUST consult with a licensed insurance professional and review actual policy documents before making any insurance '
                  'purchase decisions. This application assumes NO LIABILITY for any decisions or actions taken based on its content.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800, // Darker text for readability on light background
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}