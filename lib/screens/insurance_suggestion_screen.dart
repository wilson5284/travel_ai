// lib/screens/insurance_suggestion_screen.dart
import 'package:flutter/material.dart';
import '../services/insurance_api_service.dart';
import '../widgets/bottom_nav_bar.dart';

class InsuranceSuggestionScreen extends StatefulWidget {
  const InsuranceSuggestionScreen({super.key});

  @override
  State<InsuranceSuggestionScreen> createState() => _InsuranceSuggestionScreenState();
}

class _InsuranceSuggestionScreenState extends State<InsuranceSuggestionScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _activitiesController = TextEditingController();

  List<String> _suggestions = [];
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _generateInsuranceSuggestions() async {
    setState(() {
      _isLoading = true;
      _suggestions = [];
      _errorMessage = '';
    });

    if (_destinationController.text.isEmpty || _durationController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter destination and duration.';
        _isLoading = false;
      });
      return;
    }

    try {
      final String destination = _destinationController.text;
      final int durationDays = int.tryParse(_durationController.text) ?? 0;
      final String activities = _activitiesController.text;

      if (durationDays <= 0) {
        setState(() {
          _errorMessage = 'Duration must be a positive number.';
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> apiResponse = await InsuranceApiService.getInsuranceSuggestions(
        destination: destination,
        durationDays: durationDays,
        activities: activities,
      );

      if (apiResponse.containsKey('error')) {
        setState(() {
          _errorMessage = apiResponse['error'];
        });
      } else if (apiResponse.containsKey('insurance_suggestions')) {
        setState(() {
          _suggestions = List<String>.from(apiResponse['insurance_suggestions']);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate suggestions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Advisor 🛡️', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- UPDATED TEXTFIELD STYLING ---
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination (e.g., Japan, Europe)',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true, // Crucial: enable fill color
                fillColor: Colors.black45, // Dark fill color
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Consistent padding
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration in Days (e.g., 7)',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true, // Crucial: enable fill color
                fillColor: Colors.black45, // Dark fill color
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Consistent padding
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _activitiesController,
              decoration: const InputDecoration(
                labelText: 'Planned Activities (Optional, e.g., skiing, diving)',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true, // Crucial: enable fill color
                fillColor: Colors.black45, // Dark fill color
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Consistent padding
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // --- UPDATED BUTTON STYLING ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateInsuranceSuggestions,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.travel_explore, color: Colors.white),
                label: Text(
                  _isLoading ? 'Generating...' : 'Get Insurance Suggestions',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF), // Vibrant blue from other screens
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // --- END UPDATED BUTTON STYLING ---

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red[900]?.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              child: const Text(
                "IMPORTANT DISCLAIMER: These suggestions are AI-generated for informational purposes only and do not constitute financial or legal advice. Always consult a licensed insurance professional, thoroughly read policy documents, and compare multiple options before making any purchase decisions. Your specific needs may vary.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            if (_suggestions.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[900], // This background might still be slightly lighter than chatbot's message area
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Insurance Suggestions 🛡️",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._suggestions.map((suggestion) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "• $suggestion",
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                      ],
                    )).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}