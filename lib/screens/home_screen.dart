// lib/screens/home_screen.dart - COMPLETE HOMEPAGE WITH BANNER INTEGRATION
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/ad_banner_widget.dart';
import 'dynamic_itinerary/itinerary_screen.dart';
import 'insurance_suggestion_screen.dart';
import 'emergency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _baseCurrency;
  String _targetCurrency = 'MYR';
  double? _convertedAmount;
  final TextEditingController _amountController = TextEditingController();
  final List<String> _currencies = ['USD', 'EUR', 'MYR', 'JPY', 'GBP', 'CAD', 'AUD', 'SGD', 'CNY'];

  // Color scheme
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _violet = const Color(0xFF6A1B9A);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _loadUserCurrency();
    _loadCachedAmount();
  }

  Future<void> _loadUserCurrency() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final preferredCurrency = doc.data()?['preferredCurrency'] ?? 'USD';

        final validPreferred = _currencies.contains(preferredCurrency) ? preferredCurrency : 'USD';

        String defaultTarget = _currencies.firstWhere(
              (c) => c != validPreferred,
          orElse: () => validPreferred == 'USD' ? 'MYR' : 'USD',
        );

        setState(() {
          _baseCurrency = validPreferred;
          _targetCurrency = defaultTarget;
        });
      } catch (e) {
        print("Error loading user currency from Firestore: $e");
        setState(() {
          _baseCurrency = 'USD';
          _targetCurrency = 'MYR';
        });
        _showSnackBar('Failed to load preferred currency. Using defaults.', backgroundColor: Colors.orange);
      }
    } else {
      setState(() {
        _baseCurrency = 'USD';
        _targetCurrency = 'MYR';
      });
    }
  }

  Future<void> _loadCachedAmount() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAmount = prefs.getString('last_amount');
    if (cachedAmount != null) {
      _amountController.text = cachedAmount;
    }
  }

  Future<void> _cacheAmount(String amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_amount', amount);
  }

  Future<void> _saveConversionToFirestore(double amount, double result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final historyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('conversion_history');

      await historyRef.add({
        'timestamp': Timestamp.now(),
        'baseCurrency': _baseCurrency,
        'targetCurrency': _targetCurrency,
        'amount': amount,
        'result': result,
      });
    } catch (e) {
      print("Error saving conversion to Firestore: $e");
      _showSnackBar('Failed to save conversion history.', backgroundColor: Colors.red);
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
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

  Future<void> _convertCurrency() async {
    if (_baseCurrency == null || _targetCurrency.isEmpty) {
      _showSnackBar('Please select both currencies.');
      return;
    }

    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter an amount.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount.');
      return;
    }

    setState(() {
      _convertedAmount = null;
    });

    const String apiKey = 'fb86156312e869b5e58cc332';
    final url = Uri.parse(
      'https://v6.exchangerate-api.com/v6/$apiKey/pair/$_baseCurrency/$_targetCurrency/$amount',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'success') {
          final result = data['conversion_result']?.toDouble();
          setState(() {
            _convertedAmount = result;
          });

          if (result != null) {
            await _saveConversionToFirestore(amount, result);
            await _cacheAmount(amount.toString());
          }
        } else {
          _showSnackBar('API Error: ${data['error-type'] ?? 'Unknown error'}');
        }
      } else {
        _showSnackBar('Failed to fetch conversion rates: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}');
    }
  }

  void _swapCurrencies() {
    if (_baseCurrency != null && _targetCurrency.isNotEmpty) {
      setState(() {
        final temp = _baseCurrency!;
        _baseCurrency = _targetCurrency;
        _targetCurrency = temp;
        _convertedAmount = null;
      });
    }
  }

  InputDecoration _buildInputDecoration(String labelText, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: _darkPurple.withValues(alpha: 0.8),
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: _mediumPurple)
          : null,
      filled: true,
      fillColor: _lightBeige.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _mediumPurple.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _mediumPurple.withValues(alpha: 0.4),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Travel AI',
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
              child: _baseCurrency == null
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_darkPurple),
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BANNER - This will automatically track impressions and clicks
                    const AdBannerWidget(
                      position: 'top',
                      height: 120,
                      margin: EdgeInsets.only(bottom: 20),
                    ),

                    // Currency Converter Section
                    Text(
                      'Currency Converter',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Real-time exchange rates to plan your journey effortlessly.',
                      style: TextStyle(
                        fontSize: 16,
                        color: _greyText,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: _white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.1),
                            spreadRadius: 2,
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _darkPurple.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _baseCurrency,
                                      decoration: _buildInputDecoration('', prefixIcon: Icons.currency_exchange),
                                      items: _currencies
                                          .map((currency) => DropdownMenuItem(
                                        value: currency,
                                        child: Text(
                                          currency,
                                          style: TextStyle(color: _darkPurple),
                                        ),
                                      ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          final newTarget = _currencies.firstWhere(
                                                (c) => c != val,
                                            orElse: () => val == 'USD' ? 'MYR' : 'USD',
                                          );
                                          setState(() {
                                            _baseCurrency = val;
                                            _targetCurrency = newTarget;
                                            _convertedAmount = null;
                                          });
                                        }
                                      },
                                      dropdownColor: _white,
                                      style: TextStyle(color: _darkPurple),
                                      icon: Icon(Icons.arrow_drop_down, color: _mediumPurple),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _mediumPurple.withValues(alpha: 0.1),
                                    border: Border.all(color: _mediumPurple.withValues(alpha: 0.3)),
                                  ),
                                  child: IconButton(
                                    onPressed: _swapCurrencies,
                                    icon: Icon(
                                      Icons.swap_horiz,
                                      color: _darkPurple,
                                      size: 32,
                                    ),
                                    tooltip: "Swap Currencies",
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _darkPurple.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _currencies.contains(_targetCurrency) &&
                                          _targetCurrency != _baseCurrency
                                          ? _targetCurrency
                                          : null,
                                      decoration: _buildInputDecoration('', prefixIcon: Icons.compare_arrows),
                                      items: _currencies
                                          .where((c) => c != _baseCurrency)
                                          .map((currency) => DropdownMenuItem(
                                        value: currency,
                                        child: Text(
                                          currency,
                                          style: TextStyle(color: _darkPurple),
                                        ),
                                      ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _targetCurrency = val;
                                            _convertedAmount = null;
                                          });
                                        }
                                      },
                                      dropdownColor: _white,
                                      style: TextStyle(color: _darkPurple),
                                      icon: Icon(Icons.arrow_drop_down, color: _mediumPurple),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration('Amount', prefixIcon: Icons.money),
                            style: TextStyle(
                              color: _darkPurple,
                              fontSize: 16,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _convertCurrency,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _darkPurple,
                                foregroundColor: _white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 3,
                                shadowColor: Colors.deepPurple.withValues(alpha: 0.3),
                              ),
                              child: const Text(
                                "CONVERT CURRENCY",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_convertedAmount != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _lightPurple.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _mediumPurple.withValues(alpha: 0.4),
                                ),
                              ),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    color: _darkPurple,
                                    fontSize: 18,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _amountController.text,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: " $_baseCurrency = "),
                                    TextSpan(
                                      text: "${_convertedAmount!.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _violet,
                                      ),
                                    ),
                                    TextSpan(text: " $_targetCurrency"),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // MIDDLE BANNER - Shown between content sections
                    const AdBannerWidget(
                      position: 'middle',
                      height: 100,
                      margin: EdgeInsets.symmetric(vertical: 20),
                    ),

                    // Plan Your Next Adventure Section
                    Text(
                      'Plan Your Next Adventure',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let our AI generate a personalized travel itinerary for you.',
                      style: TextStyle(
                        fontSize: 16,
                        color: _greyText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Generate New Itinerary Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ItineraryScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFFC86FAE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withValues(alpha: 0.2),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Generate New Itinerary',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _white,
                                  ),
                                ),
                                Icon(Icons.travel_explore, color: _white, size: 36),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tell us your destination, dates, and budget, and get a custom trip plan in seconds!',
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
                    const SizedBox(height: 24),

                    // Travel Insurance Advisor Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const InsuranceSuggestionScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFFC86FAE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withValues(alpha: 0.2),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Travel Insurance Advisor',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _white,
                                  ),
                                ),
                                Icon(Icons.shield_moon_outlined, color: _white, size: 36),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Get general suggestions for travel insurance based on your trip details.',
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
                    const SizedBox(height: 24),

                    // Emergency Services Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EmergencyScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.2),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Emergency Services',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _white,
                                  ),
                                ),
                                Icon(Icons.warning_amber_rounded, color: _white, size: 36),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Find local emergency contacts and important information for your destination.',
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

                    // BOTTOM BANNER - Shown at the end of content
                    const AdBannerWidget(
                      position: 'bottom',
                      height: 120,
                      margin: EdgeInsets.symmetric(vertical: 20),
                    ),

                    // Additional Features Section
                    const SizedBox(height: 20),
                    Text(
                      'Additional Features',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Access Cards
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.history, color: Colors.blue.shade600, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Conversion\nHistory',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade50, Colors.green.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.favorite, color: Colors.green.shade600, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Saved\nItineraries',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.language, color: Colors.orange.shade600, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Language\nGuide',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.purple.shade50, Colors.purple.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.settings, color: Colors.purple.shade600, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'App\nSettings',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}