import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../db/user_service.dart';
import '../../model/user_model.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _rePasswordController = TextEditingController();
  String _preferredLanguage = 'English';
  String _preferredCurrency = 'USD';
  String? _gender = 'Male';
  bool _isLoading = false;

  // Helper function to show a SnackBar message
  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Validation methods
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required.';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters long.';
    }
    // Regex to ensure no numbers or symbols
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Username can only contain letters and spaces.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    // More robust regex for email validation
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim())) {
      return 'Please enter a valid email format (e.g., example@domain.com).';
    }
    return null;
  }

  String? _validateCountry(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Country is required.';
    }
    // Regex to ensure no numbers or symbols
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Country can only contain letters and spaces.';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    // Regex to ensure only digits
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Phone number can only contain digits.';
    }
    if (value.trim().length < 7) {
      return 'Phone number must be at least 7 digits long.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 5) {
      return 'Password must be at least 5 characters long.';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one symbol (!@#\$%^&*(),.?":{}|<>).';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please correct the errors in the form.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await fbAuth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final newUser = UserModel(
        uid: cred.user!.uid,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        preferredLanguage: _preferredLanguage,
        preferredCurrency: _preferredCurrency,
        country: _countryController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _gender,
        dob: _dobController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
        role: 'user',
        avatarUrl: null,
      );

      await UserService().addUser(newUser, cred.user!.uid);

      if (context.mounted) {
        _showSnackBar('Registration successful!', backgroundColor: Colors.green.shade700);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } on fbAuth.FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'The email address is already in use by another account.';
          break;
        case 'weak-password':
          errorMessage = 'The password provided is too weak. Please choose a stronger password.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message ?? 'An unknown error occurred.'}';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('An unexpected error occurred. Please try again.');
      print('Registration error: $e'); // Log the error for debugging
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define color scheme consistent with other screens
    final Color darkPurple = const Color(0xFF6A1B9A);
    final Color mediumPurple = const Color(0xFF9C27B0);
    final Color lightPurple = const Color(0xFFF3E5F5);
    final Color lightBeige = const Color(0xFFFFF5E6);
    final Color white = Colors.white;
    final Color greyText = Colors.grey.shade600;

    // Helper for InputDecoration consistent styling
    InputDecoration _buildInputDecoration(String labelText, IconData icon) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: darkPurple.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: mediumPurple),
        filled: true,
        fillColor: lightBeige.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: mediumPurple.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: mediumPurple.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: darkPurple,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder( // Style for error state
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder( // Style for focused error state
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2.0,
          ),
        ),
        // FIX: Ensure error text can wrap and is readable
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12, // Slightly smaller font size for more content
          height: 1.2, // Adjust line height for better spacing
        ),
        helperMaxLines: 3, // Allow helper text to wrap up to 3 lines (though not used for errors here, good for general input)
      );
    }

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Travel-themed header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: darkPurple.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.airplanemode_active,
                    size: 60,
                    color: darkPurple,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Join Our Travel Community',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: darkPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account to begin exploring',
                  style: TextStyle(
                    color: greyText,
                  ),
                ),
                const SizedBox(height: 30),

                // Registration Form Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: white.withOpacity(0.8),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Username
                          TextFormField(
                            controller: _usernameController,
                            decoration: _buildInputDecoration('Username', Icons.person_outline),
                            validator: _validateUsername,
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _buildInputDecoration('Email', Icons.mail_outline),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),

                          // Country
                          TextFormField(
                            controller: _countryController,
                            decoration: _buildInputDecoration('Country', Icons.location_on_outlined),
                            validator: _validateCountry,
                          ),
                          const SizedBox(height: 16),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
                            validator: _validatePhoneNumber,
                          ),
                          const SizedBox(height: 16),

                          // Gender
                          DropdownButtonFormField<String>(
                            value: _gender,
                            items: ['Male', 'Female', 'Other']
                                .map((gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(
                                gender,
                                style: TextStyle(color: darkPurple),
                              ),
                            ))
                                .toList(),
                            onChanged: (val) => setState(() => _gender = val!),
                            decoration: _buildInputDecoration('Gender', Icons.person_outline),
                            validator: (value) => value == null ? 'Please select your gender.' : null,
                            dropdownColor: white,
                            style: TextStyle(color: darkPurple, fontSize: 16), // Text style for selected value
                            iconEnabledColor: mediumPurple, // Dropdown arrow color
                          ),
                          const SizedBox(height: 16),

                          // Date of Birth
                          TextFormField(
                            controller: _dobController,
                            readOnly: true,
                            decoration: _buildInputDecoration('Date of Birth', Icons.calendar_today_outlined).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(Icons.calendar_month, color: mediumPurple),
                                onPressed: () => _selectDate(context),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Please select your date of birth.' : null,
                            onTap: () => _selectDate(context),
                          ),
                          const SizedBox(height: 16),

                          // Preferred Language
                          DropdownButtonFormField(
                            value: _preferredLanguage,
                            items: ['English', 'Spanish', 'French', 'Japanese', 'Chinese']
                                .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                lang,
                                style: TextStyle(color: darkPurple),
                              ),
                            ))
                                .toList(),
                            onChanged: (val) => setState(() => _preferredLanguage = val!),
                            decoration: _buildInputDecoration('Preferred Language', Icons.language_outlined),
                            dropdownColor: white,
                            style: TextStyle(color: darkPurple, fontSize: 16),
                            iconEnabledColor: mediumPurple,
                          ),
                          const SizedBox(height: 16),

                          // Preferred Currency
                          DropdownButtonFormField(
                            value: _preferredCurrency,
                            items: ['USD', 'EUR', 'GBP', 'JPY', 'MYR']
                                .map((cur) => DropdownMenuItem(
                              value: cur,
                              child: Text(
                                cur,
                                style: TextStyle(color: darkPurple),
                              ),
                            ))
                                .toList(),
                            onChanged: (val) => setState(() => _preferredCurrency = val!),
                            decoration: _buildInputDecoration('Preferred Currency', Icons.attach_money_outlined),
                            dropdownColor: white,
                            style: TextStyle(color: darkPurple, fontSize: 16),
                            iconEnabledColor: mediumPurple,
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _buildInputDecoration('Password', Icons.lock_outline),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password
                          TextFormField(
                            controller: _rePasswordController,
                            obscureText: true,
                            decoration: _buildInputDecoration('Confirm Password', Icons.lock_outline),
                            validator: _validateConfirmPassword,
                          ),
                          const SizedBox(height: 30),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkPurple,
                                foregroundColor: white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                shadowColor: darkPurple.withOpacity(0.3),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                                  : const Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Login Prompt
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(color: greyText),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                ),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: darkPurple,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
