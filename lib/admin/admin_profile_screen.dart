// lib//admin/admin_profile_screen.dart - UPDATED WITH REAL ADMIN FEATURES
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import '../../db/user_service.dart';
import '../../model/user_model.dart';
import '../../widgets/admin_bottom_nav_bar.dart';
import '../screens/user_management/edit_screen.dart';
import '../screens/user_management/login_screen.dart';
import 'banner_management_screen.dart';
import 'banner_analytics_screen.dart';
import 'system_health_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final UserService _userService = UserService();
  UserModel? _userModel;
  bool _isLoading = true;
  String? _errorMessage;

  // Report counts - Updated with banner data
  int _pendingReportsCount = 0;
  int _totalUsersCount = 0;
  int _announcementsCount = 0;
  int _activeBannersCount = 0;

  // Consistent Color Scheme (matching user profile)
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAdminStats();
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
      if (doc.exists) {
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

  Future<void> _fetchAdminStats() async {
    try {
      // Fetch pending reports count
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // Fetch total users count
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();

      // Fetch announcements count
      final announcementsSnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .count()
          .get();

      // Fetch active banners count
      final bannersSnapshot = await FirebaseFirestore.instance
          .collection('ad_banners')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      setState(() {
        _pendingReportsCount = reportsSnapshot.count ?? 0;
        _totalUsersCount = usersSnapshot.count ?? 0;
        _announcementsCount = announcementsSnapshot.count ?? 0;
        _activeBannersCount = bannersSnapshot.count ?? 0;
      });
    } catch (e) {
      print('Error fetching admin stats: $e');
    }
  }

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    await _fetchUserData();
    await _fetchAdminStats();
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        shadowColor: _mediumPurple.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_white, _lightPurple.withValues(alpha: 0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: _greyText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminOption(
      BuildContext context, {
        required String title,
        required IconData icon,
        String? subtitle,
        Widget? trailingWidget,
        VoidCallback? onTap,
        Color iconColor = Colors.black,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: _mediumPurple.withValues(alpha: 0.2),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_offWhite, _lightPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
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
                  if (trailingWidget == null) Icon(Icons.arrow_forward_ios, size: 20, color: _mediumPurple.withValues(alpha: 0.7)),
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
          title: Text('Admin Profile', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
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
            child: Text(
              'Error: $_errorMessage',
              style: TextStyle(color: Colors.red.shade700, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Admin Profile', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Admin Info
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EditProfileScreen(user: _userModel!)));
                  _refreshProfile();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_mediumPurple, _darkPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: _lightPurple,
                          backgroundImage: _userModel?.avatarUrl != null && _userModel!.avatarUrl!.isNotEmpty
                              ? NetworkImage(_userModel!.avatarUrl!)
                              : null,
                          child: _userModel?.avatarUrl == null || _userModel!.avatarUrl!.isEmpty
                              ? Icon(Icons.admin_panel_settings, size: 50, color: _mediumPurple)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userModel?.username ?? 'Admin',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: _darkPurple),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userModel?.email ?? 'admin@example.com',
                        style: TextStyle(fontSize: 16, color: _greyText),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _darkPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ADMINISTRATOR',
                          style: TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                              color: _mediumPurple.withValues(alpha: 0.2),
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
              const SizedBox(height: 20),

              // Admin Statistics - Updated with banner stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkPurple,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Pending\nReports',
                        count: _pendingReportsCount.toString(),
                        icon: Icons.report_problem,
                        iconColor: Colors.orange,
                        onTap: () => Navigator.pushNamed(context, '/admin/reports'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total\nUsers',
                        count: _totalUsersCount.toString(),
                        icon: Icons.people,
                        iconColor: Colors.blue,
                        onTap: () => Navigator.pushNamed(context, '/admin/users'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Active\nBanners',
                        count: _activeBannersCount.toString(),
                        icon: Icons.ad_units,
                        iconColor: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BannerManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Admin Management Options - Only System Health
              _buildAdminOption(
                context,
                title: 'System Health',
                icon: Icons.health_and_safety,
                iconColor: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SystemHealthScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildAdminOption(
                context,
                title: 'Logout',
                icon: Icons.logout,
                iconColor: Colors.grey.shade700,
                onTap: () async {
                  await _userService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                        context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                  }
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 3),
    );
  }
}