import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_nav_bar.dart';

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
  final List<String> _currencies = ['USD', 'EUR', 'MYR', 'JPY'];

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
      final defaultTarget = _currencies.firstWhere((c) => c != preferredCurrency);

      setState(() {
        _baseCurrency = preferredCurrency;
        _targetCurrency = defaultTarget;
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

  Future<void> _convertCurrency() async {
    if (_amountController.text.isEmpty || _baseCurrency == null || _targetCurrency.isEmpty) return;

    final amount = _amountController.text.trim();
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
}
