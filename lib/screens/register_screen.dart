// lib/screens/register_screen.dart
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../db/user_service.dart';
import '../../model/user_model.dart';
import 'login_screen.dart';
import 'dart:io';

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
  XFile? _image;
  bool _isLoading = false;

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (value.trim().length < 3) return 'At least 3 characters';
    return null;
  }

  String? _validateCountry(String? value) {
    if (value == null || value.trim().isEmpty) return 'Country is required';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value.trim())) {
      return 'Only letters and spaces';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final v = value.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
      return 'Numbers only';
    }
    if (v.length < 7 || v.length > 15) {
      return '7–15 digits';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final v = value.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(v)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    final pattern = RegExp(r'^(?=.*[A-Z])(?=.*[!@#\$&*]).{6,}$');
    if (!pattern.hasMatch(value)) {
      return 'Min 6 chars, 1 uppercase & 1 special';
    }
    return null;
  }

  String? _validateGender(String? value) {
    if (value == null || value.trim().isEmpty) return 'Gender is required';
    return null;
  }

  Future<void> _selectDate(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobController.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _rePasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords don't match!")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await fbAuth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user!.uid;

      final newUser = UserModel(
        uid: uid,
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

      await UserService().addUser(newUser, uid, image: _image);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on fbAuth.FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message ?? 'Unknown error'}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GOGOGO'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text('Register', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _image != null ? FileImage(File(_image!.path)) : null,
                  child: _image == null ? const Icon(Icons.person, size: 50) : null,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _pickImage,
                child: const Text('Select Avatar', style: TextStyle(color: Colors.blue)),
              ),
              const SizedBox(height: 20),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validateUsername,
              ),
              const SizedBox(height: 15),

              // Country
              TextFormField(
                controller: _countryController,
                decoration: InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validateCountry,
              ),
              const SizedBox(height: 15),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 15),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 15),

              // Gender
              DropdownButtonFormField<String>(
                value: _gender,
                items: ['Male', 'Female']
                    .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                    .toList(),
                onChanged: (val) => setState(() => _gender = val!),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validateGender,
              ),
              const SizedBox(height: 15),

              // Date of birth
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of birth',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Please select DOB' : null,
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 15),

              // Preferred Language
              DropdownButtonFormField(
                value: _preferredLanguage,
                items: ['English', 'Spanish', 'Malay', 'Chinese']
                    .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                    .toList(),
                onChanged: (val) => setState(() => _preferredLanguage = val!),
                decoration: InputDecoration(
                  labelText: 'Preferred Language',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),

              // Preferred Currency
              DropdownButtonFormField(
                value: _preferredCurrency,
                items: ['USD', 'EUR', 'MYR', 'JPY']
                    .map((cur) => DropdownMenuItem(value: cur, child: Text(cur)))
                    .toList(),
                onChanged: (val) => setState(() => _preferredCurrency = val!),
                decoration: InputDecoration(
                  labelText: 'Preferred Currency',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 15),

              // Re-enter Password
              TextFormField(
                controller: _rePasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Re-enter Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please re-enter password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Register button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}