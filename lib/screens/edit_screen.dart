// lib/screens/edit_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart'; // Import your UserModel

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedGender;
  late TextEditingController _birthdayController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  // New fields for country, preferredCurrency, preferredLanguage
  late TextEditingController _countryController;
  late String _selectedPreferredCurrency; // For dropdown
  late TextEditingController _preferredLanguageController;

  bool _isLoading = false;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];

  // Example currency options - you might want a more comprehensive list
  final List<String> _currencyOptions = [
    'USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'SGD', 'MYR', 'CNY', 'INR'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.username);
    _selectedGender = (widget.user.gender != null && _genderOptions.contains(widget.user.gender!))
        ? widget.user.gender!
        : 'Prefer not to say';
    _birthdayController = TextEditingController(text: widget.user.dob);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email);

    // Initialize new controllers/variables
    _countryController = TextEditingController(text: widget.user.country);
    // Ensure preferredCurrency is initialized to a valid option or a default
    _selectedPreferredCurrency = (widget.user.preferredCurrency != null && _currencyOptions.contains(widget.user.preferredCurrency!))
        ? widget.user.preferredCurrency!
        : 'MYR'; // Default to MYR or another suitable currency
    _preferredLanguageController = TextEditingController(text: widget.user.preferredLanguage);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    // Dispose new controllers
    _countryController.dispose();
    _preferredLanguageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'username': _nameController.text.trim(),
        'gender': _selectedGender,
        'dob': _birthdayController.text.trim(),
        'phone': _phoneController.text.trim(),
        // Save new fields
        'country': _countryController.text.trim(),
        'preferredCurrency': _selectedPreferredCurrency,
        'preferredLanguage': _preferredLanguageController.text.trim(),
        // email, uid, role, createdAt are not updated here as per your request
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildEditableInfoRow({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              border: readOnly ? InputBorder.none : const UnderlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
            ),
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            validator: (value) {
              if (label == 'Name' && (value == null || value.isEmpty)) {
                return 'Name cannot be empty';
              }
              // Add validation for other fields as needed
              return null;
            },
            onTap: onTap,
          ),
          if (!readOnly) const SizedBox(height: 8),
          if (!readOnly) const Divider(height: 1),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_birthdayController.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked.toString().split(' ')[0] != _birthdayController.text) {
      setState(() {
        _birthdayController.text = picked.toString().split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[700],
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                color: Colors.red[700],
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: widget.user.avatarUrl != null
                            ? NetworkImage(widget.user.avatarUrl!)
                            : null,
                        child: widget.user.avatarUrl == null
                            ? const Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                        backgroundColor: Colors.red[400],
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Change profile picture (not implemented).')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Edit', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildEditableInfoRow(label: 'Name', controller: _nameController),

              // Gender Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                      ),
                      items: _genderOptions.map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGender = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty || value == 'Prefer not to say') {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                  ],
                ),
              ),

              _buildEditableInfoRow(
                label: 'Birthday',
                controller: _birthdayController,
                keyboardType: TextInputType.datetime,
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              _buildEditableInfoRow(label: 'Phone', controller: _phoneController, keyboardType: TextInputType.phone),
              _buildEditableInfoRow(label: 'Email', controller: _emailController, readOnly: true),

              // New fields: Country, Preferred Currency, Preferred Language
              _buildEditableInfoRow(label: 'Country', controller: _countryController),

              // Preferred Currency Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preferred Currency',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedPreferredCurrency,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                      ),
                      items: _currencyOptions.map((String currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPreferredCurrency = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a preferred currency';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                  ],
                ),
              ),

              _buildEditableInfoRow(label: 'Preferred Language', controller: _preferredLanguageController),


              const SizedBox(height: 20),
              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}