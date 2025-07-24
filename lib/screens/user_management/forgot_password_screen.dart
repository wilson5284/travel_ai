import 'package:flutter/material.dart';
import '../../services/auth_service.dart'; // Import your AuthService

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService(); // Use AuthService
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  void _showSnackBar(String message, {Color backgroundColor = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Please enter your email address!');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Use the AuthService to send the password reset email
      await _authService.sendPasswordResetEmail(email);
      _showSnackBar(
        'Password reset link sent to your email!',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context);
    } catch (e) {
      String errorMessage = 'Error: ${e.toString()}';
      // You can add more specific Firebase Auth error handling here if needed
      // For example: if (e is FirebaseAuthException) { errorMessage = e.message ?? 'Unknown Firebase error'; }
      _showSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
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
        child: Center( // Use Center for consistent centering
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Travel-themed header (Copied from Login/Register Screen)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    size: 60,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Forgot Your Password?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email to receive a reset link',
                  style: TextStyle(
                    color: Colors.deepPurple.shade600,
                  ),
                ),
                const SizedBox(height: 30),

                // Form Card (Copied from Login/Register Screen)
                Card(
                  elevation: 0, // Match login/register card elevation
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white.withOpacity(0.8), // Match login/register card color
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Email Field (Styled to match Login/Register)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: TextStyle(color: Colors.deepPurple.shade600),
                            prefixIcon: Icon(Icons.mail_outline, color: Colors.deepPurple.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple.shade200,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.deepPurple.shade400,
                                width: 2.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30), // Increased spacing for button

                        // Reset Button (Styled to match Login/Register)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A1B9A), // Consistent violet
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              shadowColor: Colors.deepPurple.withOpacity(0.3),
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
                              'SEND RESET LINK',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Back to Login Prompt (Styled to match Login/Register)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Remember your password? ",
                      style: TextStyle(color: Colors.deepPurple.shade600),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context), // Pop to go back to LoginScreen
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.deepPurple.shade800,
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
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}