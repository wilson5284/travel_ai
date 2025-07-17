// lib/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import '../db/user_service.dart';
import '../model/user_model.dart';
import '../widgets/bottom_nav_bar.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  UserModel? _userModel;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final fbUser = fbAuth.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      setState(() {
        _errorMessage = 'No user is logged in.';
        _isLoading = false;
      });
      return;
    }
    final uid = fbUser.uid;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'username': fbUser.displayName ?? '',
          'email': fbUser.email ?? '',
          'preferredLanguage': 'English',
          'preferredCurrency': 'USD',
          'country': '',
          'phone': '',
          'gender': '',
          'dob': '',
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'Trainee',
        });
      }
      final data = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data()!;
      setState(() {
        _userModel = UserModel.fromMap(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    await _fetchUserData();
  }

  Widget _buildInfoRow(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const Spacer(),
          Text(value ?? '-', style: const TextStyle(fontSize: 16, color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshProfile),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(_userModel?.username ?? '-', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_userModel?.email ?? '-', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            _buildInfoRow('Role', _userModel?.role, Icons.work),
            _buildInfoRow('Date of Birth', _userModel?.dob, Icons.cake),
            _buildInfoRow('Gender', _userModel?.gender, Icons.person),
            _buildInfoRow('Country', _userModel?.country, Icons.flag),
            _buildInfoRow('Phone', _userModel?.phone, Icons.phone),
            _buildInfoRow('Preferred Language', _userModel?.preferredLanguage, Icons.language),
            _buildInfoRow('Preferred Currency', _userModel?.preferredCurrency, Icons.attach_money),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: _userModel!)));
                _refreshProfile();
              },
              icon: const Icon(Icons.edit),
              label: const Text("Edit Profile"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await _userService.signOut();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}