// lib/screens/emergency_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final TextEditingController _countryCodeController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();

  Map<String, dynamic>? _emergencyData;
  String? _error;
  bool _isLoading = false; // Add a loading state

  // Color scheme (copied from your home_screen for consistency)
  final Color _white = Colors.white;
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
      final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;

  // Simple country list with common countries. You can expand this.
  // Consider moving this to a separate utility file if it gets very large.
  final List<Map<String, String>> countries = [
    {'code': 'MY', 'name': 'Malaysia'},
    {'code': 'US', 'name': 'United States'},
    {'code': 'SG', 'name': 'Singapore'},
    {'code': 'JP', 'name': 'Japan'},
    {'code': 'TH', 'name': 'Thailand'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'UK', 'name': 'United Kingdom'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'CN', 'name': 'China'},
    {'code': 'KR', 'name': 'South Korea'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'ID', 'name': 'Indonesia'},
    {'code': 'VN', 'name': 'Vietnam'},
    {'code': 'PH', 'name': 'Philippines'},
    {'code': 'NZ', 'name': 'New Zealand'},
    {'code': 'IT', 'name': 'Italy'},
    {'code': 'ES', 'name': 'Spain'},
    {'code': 'BR', 'name': 'Brazil'},
    {'code': 'MX', 'name': 'Mexico'},
    {'code': 'AE', 'name': 'United Arab Emirates'},
    // Add more as needed
  ];

  List<Map<String, String>> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = countries;
    // Automatically fetch numbers for a default country (e.g., Malaysia) on load
    _countryCodeController.text = 'MY';
    fetchEmergencyNumbers('MY');
  }

  Future<void> fetchEmergencyNumbers(String code) async {
    final String countryCode = code.toUpperCase().trim();
    if (countryCode.isEmpty) {
      setState(() {
        _error = 'Please enter a country code.';
        _emergencyData = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emergencyData = null;
      _error = null;
    });

    final url = Uri.parse('https://emergencynumberapi.com/api/country/$countryCode');
    print('DEBUG: Attempting to fetch from URL: $url');
    try {
      final res = await http.get(url);
      print('DEBUG: Response Status Code: ${res.statusCode}');
      print('DEBUG: Response Body (start): ${res.body.substring(0, res.body.length > 500 ? 500 : res.body.length)} (end)');

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        // Check if 'error' is not empty, OR if 'data' is null/empty
        if (body['error'] != null && body['error'].isNotEmpty) {
          setState(() => _error = body['error']);
          print('DEBUG: API returned specific error: ${body['error']}');
        } else if (body['data'] == null || (body['data'] is Map && (body['data'] as Map).isEmpty)) {
          // This covers cases where 'error' is empty string but 'data' is also empty or null
          setState(() => _error = 'No specific emergency data found for this country.');
          print('DEBUG: API returned no data for $countryCode');
        }
        else {
          setState(() => _emergencyData = body['data']);
          print('DEBUG: Successfully fetched emergency data for $countryCode');
        }
      } else {
        setState(() => _error = 'API Error: Status ${res.statusCode}');
        print('DEBUG: API returned non-200 status: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Network/Parsing Error: ${e.toString()}');
      print('Emergency API Error (Catch Block): $e');
    } finally {
      setState(() => _isLoading = false);
      print('DEBUG: Loading finished.');
    }
  }

  void _searchCountry(String query) {
    setState(() {
      _filteredCountries = countries
          .where((c) => c['name']!.toLowerCase().contains(query.toLowerCase()) ||
          c['code']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

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

  Widget _buildEmergencyDetails() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_darkPurple),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
              const SizedBox(height: 10),
              Text(
                "Error: $_error",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                "Please check the country code and your internet connection.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _greyText, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_emergencyData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: _mediumPurple, size: 48),
              const SizedBox(height: 10),
              Text(
                "Enter a country code or select from the list below to find emergency numbers.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _greyText, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    List<Widget> rows = [];

    // Country Name
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          // FIX: Changed 'Country' to 'country' to match API response casing
          "📍 Emergency Numbers for ${_emergencyData?['country']?['name'] ?? 'Unknown Country'}",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _darkPurple),
          textAlign: TextAlign.center,
        ),
      ),
    );

    // Helper to add contact tiles
    void addContactTile(String key, String label, IconData icon) {
      // Access keys safely with null-aware operators.
      // The API response is `_emergencyData['police']['all']`, `_emergencyData['ambulance']['all']`, etc.
      final List<dynamic>? numbers = _emergencyData?[key]?['all']; // Changed from 'All' to 'all' for consistency and safety
      if (numbers != null && numbers.isNotEmpty) {
        // Filter out null or empty strings if the API returns them
        final validNumbers = numbers.where((n) => n != null && n.toString().isNotEmpty).map((n) => n.toString()).toList();
        if (validNumbers.isNotEmpty) {
          rows.add(
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                leading: Icon(icon, color: Colors.red.shade700, size: 30),
                title: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: _darkPurple)),
                subtitle: Text(validNumbers.join(', '), style: TextStyle(color: _greyText, fontSize: 16)),
                onTap: () {
                  // Future: Implement direct call functionality
                  // For example: launchUrl(Uri.parse('tel:${validNumbers.first}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tapping to call ${validNumbers.first} ($label)')),
                  );
                },
              ),
            ),
          );
        }
      }
    }

    addContactTile('police', 'Police', Icons.local_police); // Changed key to lowercase 'police'
    addContactTile('ambulance', 'Ambulance', Icons.medical_services); // Changed key to lowercase 'ambulance'
    addContactTile('fire', 'Fire / Fire Department', Icons.local_fire_department); // Changed key to lowercase 'fire'
    addContactTile('dispatch', 'General Dispatch / Operator', Icons.call); // Changed key to lowercase 'dispatch'

    // Check for 112 Universal Emergency
    // FIX: Using null-aware operator for 'member_112'
    if (_emergencyData?['member_112'] == true) { // Changed 'Member_112' to 'member_112'
      rows.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: _lightPurple.withOpacity(0.7),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            leading: Icon(Icons.emergency_outlined, color: _mediumPurple, size: 30),
            title: Text('112 Universal Emergency Number', style: TextStyle(fontWeight: FontWeight.bold, color: _darkPurple)),
            subtitle: Text('112 is active and universally recognized in this country.', style: TextStyle(color: _greyText, fontSize: 15)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tapping to call 112')),
              );
            },
          ),
        ),
      );
    }
    // Add a message if no specific numbers were found for the common categories
    // This condition should now correctly identify if no emergency numbers were added.
    if (rows.length == 1 && rows[0] is Padding && (rows[0] as Padding).child is Text && ((rows[0] as Padding).child as Text).data!.contains('Emergency Numbers for')) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No specific emergency numbers found for typical categories (Police, Ambulance, Fire) for this country. Please try a different country or consult local guides.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _greyText, fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }


    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contact Finder'),
        backgroundColor: Colors.red.shade700, // Matching the emergency button color
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lightPurple, // Light violet
              _lightBeige, // Light beige
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24), // Consistent padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Emergency Services',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get critical emergency numbers for any country you visit.',
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText,
                ),
              ),
              const SizedBox(height: 24),
              // Search by Country Code Section
              Container(
                decoration: BoxDecoration(
                  color: _white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1), // Adjusted shadow color
                      spreadRadius: 2,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search by ISO Country Code',
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
                          child: TextField(
                            controller: _countryCodeController,
                            decoration: _buildInputDecoration(
                                'e.g. MY, US, JP',
                                prefixIcon: Icons.travel_explore
                            ),
                            style: TextStyle(color: _darkPurple),
                            textCapitalization: TextCapitalization.characters, // Auto-capitalize input
                            onSubmitted: (value) => fetchEmergencyNumbers(value), // Search on submit
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => fetchEmergencyNumbers(_countryCodeController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700, // Emergency red
                            foregroundColor: _white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            elevation: 3,
                          ),
                          child: const Text('SEARCH'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Expanded( // Use Expanded for the ListView to take available space
                child: ListView(
                  children: [
                    // Emergency Details Section (where results are shown)
                    _buildEmergencyDetails(),
                    const Divider(thickness: 1, height: 32, color: Colors.grey),
                    // Country Code Finder Section
                    Text(
                      'Or Find a Country Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _countrySearchController,
                      decoration: _buildInputDecoration('Search country name...', prefixIcon: Icons.search),
                      style: TextStyle(color: _darkPurple),
                      onChanged: _searchCountry,
                    ),
                    const SizedBox(height: 8),
                    // Filtered Country List
                    ..._filteredCountries.map((c) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        title: Text(c['name']!, style: TextStyle(color: _darkPurple)),
                        trailing: Text(c['code']!, style: TextStyle(fontWeight: FontWeight.bold, color: _mediumPurple)),
                        onTap: () {
                          _countryCodeController.text = c['code']!;
                          fetchEmergencyNumbers(c['code']!);
                          // Optional: Scroll to top of list or hide keyboard
                          FocusScope.of(context).unfocus(); // Dismiss keyboard
                          // You might want to scroll to the top of the details after selecting
                          // using a ScrollController for the ListView.
                        },
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }
}