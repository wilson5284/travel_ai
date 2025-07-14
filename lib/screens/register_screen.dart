import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  String _language = 'English';
  String _currency = 'USD';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _username, decoration: const InputDecoration(labelText: "Username")),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
              TextFormField(controller: _password, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
              DropdownButtonFormField(
                value: _language,
                items: ['English', 'Spanish', 'French', 'Chinese']
                    .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                    .toList(),
                onChanged: (val) => setState(() => _language = val!),
                decoration: const InputDecoration(labelText: "Preferred Language"),
              ),
              DropdownButtonFormField(
                value: _currency,
                items: ['USD', 'EUR', 'MYR', 'JPY']
                    .map((cur) => DropdownMenuItem(value: cur, child: Text(cur)))
                    .toList(),
                onChanged: (val) => setState(() => _currency = val!),
                decoration: const InputDecoration(labelText: "Preferred Currency"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await _authService.registerUser(
                    _email.text.trim(),
                    _password.text.trim(),
                    _username.text.trim(),
                    _language,
                    _currency,
                  );
                  Fluttertoast.showToast(msg: "Registered successfully!");
                  Navigator.pop(context);
                },
                child: const Text("Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
