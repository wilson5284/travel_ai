import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late String _language;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _language = widget.user.preferredLanguage ?? 'English';
    _currency = widget.user.preferredCurrency ?? 'USD';
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'username': _usernameController.text.trim(),
          'preferredLanguage': _language,
          'preferredCurrency': _currency,
        });
        Navigator.pop(context); // go back to profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: "Username"),
                validator: (val) => val == null || val.isEmpty ? "Please enter a username" : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _language,
                items: ['English', 'Spanish', 'French', 'Chinese']
                    .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                    .toList(),
                onChanged: (val) => setState(() => _language = val!),
                decoration: const InputDecoration(labelText: "Preferred Language"),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _currency,
                items: ['USD', 'EUR', 'MYR', 'JPY']
                    .map((cur) => DropdownMenuItem(value: cur, child: Text(cur)))
                    .toList(),
                onChanged: (val) => setState(() => _currency = val!),
                decoration: const InputDecoration(labelText: "Preferred Currency"),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveChanges,
                child: const Text("Save Changes"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
