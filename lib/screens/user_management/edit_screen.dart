// lib/screens/edit_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../model/user_model.dart'; // Import your UserModel

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

  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);


  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];

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

    _countryController = TextEditingController(text: widget.user.country);
    _selectedPreferredCurrency = (widget.user.preferredCurrency != null && _currencyOptions.contains(widget.user.preferredCurrency!))
        ? widget.user.preferredCurrency!
        : 'MYR';
    _preferredLanguageController = TextEditingController(text: widget.user.preferredLanguage);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _preferredLanguageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      // Show an error message if validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the errors in the form.', style: TextStyle(color: _white)),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'username': _nameController.text.trim(),
        'gender': _selectedGender,
        'dob': _birthdayController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country': _countryController.text.trim(),
        'preferredCurrency': _selectedPreferredCurrency,
        'preferredLanguage': _preferredLanguageController.text.trim(),
        // email, uid, role, createdAt are typically not updated from here
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!', style: TextStyle(color: _white)),
            backgroundColor: _darkPurple,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e', style: TextStyle(color: _white)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), // Consistent padding
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: _buildInputDecoration(label, prefixIcon: prefixIcon),
        style: TextStyle(fontSize: 16, color: _darkPurple),
        onTap: onTap,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: _buildInputDecoration(label, prefixIcon: prefixIcon),
        dropdownColor: _offWhite, // Background for dropdown options
        style: TextStyle(fontSize: 16, color: _darkPurple),
        icon: Icon(Icons.arrow_drop_down, color: _mediumPurple),
        items: options.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: TextStyle(color: _darkPurple)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_birthdayController.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
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
    if (picked != null && picked.toString().split(' ')[0] != _birthdayController.text) {
      setState(() {
        _birthdayController.text = picked.toString().split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set to transparent for gradient
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_darkPurple),
                strokeWidth: 2,
              ),
            )
                : Icon(Icons.check_circle_outline, color: _darkPurple, size: 28), // Larger, themed icon
            onPressed: _isLoading ? null : _saveProfile,
            tooltip: 'Save Changes',
          ),
          const SizedBox(width: 8), // Padding for the action button
        ],
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Picture Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24.0), // Increased vertical padding
                  decoration: BoxDecoration(
                    color: _white, // White background for the header
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container( // Avatar border
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_mediumPurple, _darkPurple], // Purple border
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 60, // Larger avatar
                            backgroundColor: _lightPurple, // Fallback background
                            backgroundImage: widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                                ? NetworkImage(widget.user.avatarUrl!)
                                : null,
                            child: widget.user.avatarUrl == null || widget.user.avatarUrl!.isEmpty
                                ? Icon(Icons.person, size: 60, color: _mediumPurple) // Purple icon
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Change profile picture (not implemented).', style: TextStyle(color: _white)), backgroundColor: _mediumPurple),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _mediumPurple, // Themed edit button background
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _white, width: 2), // White border
                              ),
                              child: Icon(Icons.edit, color: _white, size: 20), // Edit icon
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Editable Fields
                _buildTextField(
                  label: 'Name',
                  controller: _nameController,
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name cannot be empty';
                    }
                    return null;
                  },
                ),
                _buildDropdownField(
                  label: 'Gender',
                  value: _selectedGender,
                  options: _genderOptions,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedGender = newValue!;
                    });
                  },
                  prefixIcon: Icons.wc,
                  validator: (value) {
                    if (value == null || value.isEmpty || value == 'Prefer not to say') {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: 'Birthday',
                  controller: _birthdayController,
                  keyboardType: TextInputType.datetime,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  prefixIcon: Icons.calendar_today,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Birthday cannot be empty';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: 'Phone',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone,
                  validator: (value) {
                    // Simple phone validation
                    if (value != null && value.isNotEmpty && !RegExp(r'^[0-9+]{10,}$').hasMatch(value)) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  readOnly: true, // Email usually not editable from here
                  prefixIcon: Icons.email,
                  hintText: 'Email cannot be changed',
                ),
                _buildTextField(
                  label: 'Country',
                  controller: _countryController,
                  prefixIcon: Icons.flag,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Country cannot be empty';
                    }
                    return null;
                  },
                ),
                _buildDropdownField(
                  label: 'Preferred Currency',
                  value: _selectedPreferredCurrency,
                  options: _currencyOptions,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedPreferredCurrency = newValue!;
                    });
                  },
                  prefixIcon: Icons.currency_exchange,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a preferred currency';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: 'Preferred Language',
                  controller: _preferredLanguageController,
                  prefixIcon: Icons.language,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Language cannot be empty';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // Save Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_mediumPurple, _darkPurple], // Consistent gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15), // Consistent rounding
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
                        onTap: _isLoading ? null : _saveProfile,
                        borderRadius: BorderRadius.circular(15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: _isLoading
                              ? CircularProgressIndicator(color: _white, strokeWidth: 2)
                              : Row(
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
                ),
                const SizedBox(height: 24), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}