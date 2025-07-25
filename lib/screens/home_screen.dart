<<<<<<< HEAD
// lib/screens/home/home_screen.dart
=======
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
<<<<<<< HEAD
import '../widgets/bottom_nav_bar.dart';
import 'dynamic_itinerary/itinerary_screen.dart';
=======
import '../widgets/bottom_nav_bar.dart'; // You need to create this file
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f

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
<<<<<<< HEAD
  final List<String> _currencies = ['USD', 'EUR', 'MYR', 'JPY', 'GBP', 'CAD', 'AUD', 'SGD', 'CNY'];

  // Color scheme
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkerOffWhite = const Color(0xFFEBEBEB);
  final Color _violet = const Color(0xFF6A1B9A);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
=======
  final List<String> _currencies = ['USD', 'EUR', 'MYR', 'JPY'];
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f

  @override
  void initState() {
    super.initState();
    _loadUserCurrency();
    _loadCachedAmount();
  }

  Future<void> _loadUserCurrency() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final preferredCurrency = doc.data()?['preferredCurrency'] ?? 'USD';
<<<<<<< HEAD

      final validPreferred = _currencies.contains(preferredCurrency) ? preferredCurrency : 'USD';

      String defaultTarget = _currencies.firstWhere(
            (c) => c != validPreferred,
        orElse: () => validPreferred == 'USD' ? 'MYR' : 'USD',
      );

      setState(() {
        _baseCurrency = validPreferred;
        _targetCurrency = defaultTarget;
      });
    } else {
      setState(() {
        _baseCurrency = 'USD';
        _targetCurrency = 'MYR';
      });
=======
      final defaultTarget = _currencies.firstWhere((c) => c != preferredCurrency);

      setState(() {
        _baseCurrency = preferredCurrency;
        _targetCurrency = defaultTarget;
      });
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
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
  }

<<<<<<< HEAD
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

    // Make sure you replace 'YOUR_EXCHANGERATE_API_KEY' with your actual key
    const String apiKey = 'YOUR_EXCHANGERATE_API_KEY';
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
=======
  Future<void> _convertCurrency() async {
    if (_amountController.text.isEmpty || _baseCurrency == null || _targetCurrency.isEmpty) return;

    final amount = _amountController.text.trim();
    // Replace 'YOUR_API_KEY' with your actual ExchangeRate-API key
    final url = Uri.parse(
      'https://v6.exchangerate-api.com/v6/fb86156312e869b5e58cc332/pair/$_baseCurrency/$_targetCurrency/$amount',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['conversion_result']?.toDouble();
      final parsedAmount = double.tryParse(amount);

      setState(() {
        _convertedAmount = result;
      });

      if (parsedAmount != null && result != null) {
        await _saveConversionToFirestore(parsedAmount, result);
        await _cacheAmount(amount);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to convert currency')),
      );
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
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

<<<<<<< HEAD
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
                        color: _white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.1),
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
                                        color: _darkPurple.withOpacity(0.9),
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
                                    color: _mediumPurple.withOpacity(0.1),
                                    border: Border.all(color: _mediumPurple.withOpacity(0.3)),
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
                                        color: _darkPurple.withOpacity(0.9),
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
                                shadowColor: Colors.deepPurple.withOpacity(0.3),
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
                                color: _lightPurple.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _mediumPurple.withOpacity(0.4),
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
                    const SizedBox(height: 40), // Spacing after currency converter

                    // New Section: Make an Itinerary
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
                            colors: [Color(0xFF6A1B9A), Color(0xFFC86FAE)], // Darker purple to pinkish-purple
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.2),
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
                    const SizedBox(height: 24), // Ensure bottom padding
=======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: _baseCurrency == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Welcome to Travel AI Home!', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 30),

            // Currency Converter
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(top: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Currency Converter",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Base + Swap + Target Row
                    Row(
                      children: [
                        // Base Currency
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _baseCurrency,
                            decoration: const InputDecoration(labelText: 'Base'),
                            items: _currencies
                                .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final newTarget = _currencies.firstWhere((c) => c != val);
                                setState(() {
                                  _baseCurrency = val;
                                  _targetCurrency = newTarget;
                                  _convertedAmount = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Swap Button
                        IconButton(
                          onPressed: _swapCurrencies,
                          icon: const Icon(Icons.swap_horiz, size: 32),
                          tooltip: "Swap Currencies",
                        ),

                        const SizedBox(width: 8),

                        // Target Currency
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _currencies.contains(_targetCurrency) &&
                                _targetCurrency != _baseCurrency
                                ? _targetCurrency
                                : null,
                            decoration: const InputDecoration(labelText: 'Target'),
                            items: _currencies
                                .where((c) => c != _baseCurrency)
                                .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
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
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Amount TextField
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Convert Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _convertCurrency,
                        icon: const Icon(Icons.sync_alt),
                        label: const Text("Convert"),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Result
                    if (_convertedAmount != null)
                      Center(
                        child: Text(
                          "$_baseCurrency → $_targetCurrency = $_convertedAmount",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
                  ],
                ),
              ),
            ),
<<<<<<< HEAD
=======

            const SizedBox(height: 30),

>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
<<<<<<< HEAD

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
=======
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
}