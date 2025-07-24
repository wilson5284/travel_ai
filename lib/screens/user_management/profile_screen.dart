// lib/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import '../../db/user_service.dart'; // Assuming you have this service
import '../../model/user_model.dart'; // Assuming you have this model
import '../../widgets/bottom_nav_bar.dart'; // Assuming you have this widget
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
          'avatarUrl': null, // Default to null for avatar
        });
        // Re-fetch after creation to get the newly created data
        final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        setState(() {
          _userModel = UserModel.fromMap(updatedDoc.data()!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _userModel = UserModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      }
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
        Widget? trailingWidget, // Changed to Widget for more flexibility
        VoidCallback? onTap,
        Color iconColor = Colors.black, // Default, will be overridden by theme colors
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0), // Consistent padding
      elevation: 5, // Consistent shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Consistent card rounding
      ),
      shadowColor: _mediumPurple.withOpacity(0.2), // Consistent shadow color
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_offWhite, _lightPurple], // Lighter gradient for card background
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Material( // For InkWell ripple effect
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0), // More padding
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _darkPurple,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 14, color: _greyText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) trailingWidget,
                  if (trailingWidget == null) Icon(Icons.arrow_forward_ios, size: 20, color: _mediumPurple.withOpacity(0.7)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradientStart, _gradientEnd],
            ),
          ),
          child: Center(child: CircularProgressIndicator(color: _darkPurple)),
        ),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('User Profile', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
          backgroundColor: _white,
          foregroundColor: _darkPurple,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradientStart, _gradientEnd],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Set to transparent for gradient
      appBar: AppBar(
        title: Text('Your Profile', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0, // Remove shadow
        bottom: PreferredSize( // Add a thin bottom border for separation
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch for header
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
                  padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0), // Increased padding
                  decoration: BoxDecoration(
                    color: _white, // White background for the header
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30), // More prominent curve
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [ // Add shadow for depth
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
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
                          radius: 50, // Slightly larger avatar
                          backgroundColor: _lightPurple, // Fallback background
                          backgroundImage: _userModel?.avatarUrl != null && _userModel!.avatarUrl!.isNotEmpty
                              ? NetworkImage(_userModel!.avatarUrl!)
                              : null,
                          child: _userModel?.avatarUrl == null || _userModel!.avatarUrl!.isEmpty
                              ? Icon(Icons.person, size: 50, color: _mediumPurple) // Purple icon
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userModel?.username ?? 'Traveler Name',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: _darkPurple),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userModel?.email ?? 'user@example.com',
                        style: TextStyle(fontSize: 16, color: _greyText),
                      ),
                      if (_userModel?.country != null && _userModel!.country!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _userModel!.country!,
                          style: TextStyle(fontSize: 15, color: _greyText.withOpacity(0.8)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Edit Profile Button (Optional, as header is clickable)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_mediumPurple, _darkPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _mediumPurple.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => EditProfileScreen(user: _userModel!)));
                              _refreshProfile();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                              child: Text(
                                'Edit Profile',
                                style: TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Announcement with Badge
              _buildProfileItem(
                context,
                title: 'Announcements',
                icon: Icons.notifications,
                iconColor: Colors.blueAccent, // Distinct color
                trailingWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '34', // Example, fetch actual count
                    style: TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () {
                  // Ensure this route is defined in your main app
                  Navigator.pushNamed(context, '/announcements');
                },
              ),

              // Other Features/Actions
              _buildProfileItem(
                context,
                title: 'My Saved Places',
                icon: Icons.bookmark,
                iconColor: Colors.orangeAccent, // Distinct color
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('My Saved Places not implemented.', style: TextStyle(color: _white)), backgroundColor: _mediumPurple),
                  );
                },
              ),
              _buildProfileItem(
                context,
                title: 'Travel History',
                icon: Icons.history,
                iconColor: Colors.teal, // Distinct color
                onTap: () {
                  // Assuming you have a route to your history screen
                  Navigator.pushNamed(context, '/history');
                },
              ),
              _buildProfileItem(
                context,
                title: 'Preferences & Settings',
                icon: Icons.settings,
                iconColor: _darkPurple, // Primary purple
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Preferences not implemented.', style: TextStyle(color: _white)), backgroundColor: _mediumPurple),
                  );
                },
              ),
              _buildProfileItem(
                context,
                title: 'Help & Support',
                icon: Icons.help_outline,
                iconColor: Colors.blueGrey, // Distinct color
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Help & Support not implemented.', style: TextStyle(color: _white)), backgroundColor: _mediumPurple),
                  );
                },
              ),
              _buildProfileItem(
                context,
                title: 'Report an Issue',
                icon: Icons.report_problem,
                iconColor: Colors.redAccent, // Red for warning/issue
                onTap: () {
                  Navigator.pushNamed(context, '/report');
                },
              ),
              _buildProfileItem(
                context,
                title: 'View My Reports',
                icon: Icons.message_outlined,
                iconColor: Colors.lightBlue, // Distinct color
                onTap: () {
                  Navigator.pushNamed(context, '/report/list');
                },
              ),
              const SizedBox(height: 20), // Spacing before logout
              _buildProfileItem(
                context,
                title: 'Logout',
                icon: Icons.logout,
                iconColor: Colors.grey.shade700, // Slightly darker grey for logout
                onTap: () async {
                  await _userService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil( // Use pushAndRemoveUntil to clear navigation stack
                        context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                  }
                },
              ),
              const SizedBox(height: 30), // Increased spacing at bottom
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3), // Adjust as per your NavBar
    );
  }
}