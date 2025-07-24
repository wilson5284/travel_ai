// lib/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import '../db/user_service.dart'; // Assuming you have this service
import '../model/user_model.dart'; // Assuming you have this model
import '../widgets/bottom_nav_bar.dart'; // Assuming you have this widget
import 'edit_screen.dart'; // For Edit Profile Screen
import 'login_screen.dart'; // For logout navigation

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
        // Create a basic user document if it doesn't exist
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'username': fbUser.displayName ?? fbUser.email?.split('@')[0] ?? 'User',
          'email': fbUser.email ?? '',
          'preferredLanguage': 'English',
          'preferredCurrency': 'USD',
          'country': '',
          'phone': '',
          'gender': '',
          'dob': '',
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
          'avatarUrl': null,
        });
      }
      final userData = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data()!;
      setState(() {
        _userModel = UserModel.fromMap(userData);
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

  // Widget for common dashboard/profile items
  Widget _buildProfileItem(
      BuildContext context, {
        required String title,
        required IconData icon,
        String? subtitle,
        String? trailingText,
        VoidCallback? onTap,
        Color iconColor = Colors.black,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: (trailingText != null && trailingText.isNotEmpty)
            ? Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            trailingText,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        )
            : const Icon(Icons.arrow_forward_ios, size: 20),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Profile')),
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        automaticallyImplyLeading: false, // Keep if this is a main nav screen
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Profile Info (Clickable to EditProfileScreen)
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditProfileScreen(user: _userModel!)));
                _refreshProfile(); // Refresh data after editing
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _userModel?.avatarUrl != null
                          ? NetworkImage(_userModel!.avatarUrl!)
                          : null,
                      child: _userModel?.avatarUrl == null
                          ? const Icon(Icons.person, size: 40, color: Colors.white)
                          : null,
                      backgroundColor: Colors.blue[400],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _userModel?.username ?? 'User Name',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      _userModel?.uid ?? 'User ID', // You can display UID or another identifier
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    Text(
                      _userModel?.email ?? 'user@example.com',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Announcement with Badge
            _buildProfileItem(
              context,
              title: 'Announcement',
              icon: Icons.notifications,
              iconColor: Colors.blueGrey,
              trailingText: '34', // Example, you'd fetch this count from Firestore
              onTap: () {
                Navigator.pushNamed(context, '/announcements');
              },
            ),

            // Other Features/Actions for a general user profile
            _buildProfileItem(
              context,
              title: 'My Saved Places',
              icon: Icons.bookmark,
              iconColor: Colors.deepPurple,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('My Saved Places not implemented.')),
                );
              },
            ),
            _buildProfileItem(
              context,
              title: 'Travel History',
              icon: Icons.history,
              iconColor: Colors.brown,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Travel History not implemented.')),
                );
              },
            ),
            _buildProfileItem(
              context,
              title: 'Preferences',
              icon: Icons.settings,
              iconColor: Colors.teal,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences not implemented.')),
                );
              },
            ),
            _buildProfileItem(
              context,
              title: 'Report an Issue',
              icon: Icons.report_problem,
              iconColor: Colors.redAccent,
              onTap: () {
                Navigator.pushNamed(context, '/report');
              },
            ),
            _buildProfileItem(
              context,
              title: 'View My Reports',
              icon: Icons.message_outlined,
              iconColor: Colors.blueAccent,
              onTap: () {
                Navigator.pushNamed(context, '/report/list');
              },
            ),
            _buildProfileItem(
              context,
              title: 'Logout',
              icon: Icons.logout,
              iconColor: Colors.grey,
              onTap: () async {
                await _userService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2), // Adjust as per your NavBar
    );
  }
}


