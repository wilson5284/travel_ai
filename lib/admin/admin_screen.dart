// lib/admin/admin_screen.dart - UPDATED WITH BANNER MANAGEMENT AND CUSTOMER SUPPORT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/admin_bottom_nav_bar.dart';
import 'banner_management_screen.dart';
import '../services/admin_chat_service.dart'; // Add this import
import '../screens/admin_chat_screen.dart'; // Add this import for the individual chat screen

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  String? _avatarUrl;
  String? _username;

  // Notification count
  int _unreadNotifications = 0;

  // Statistics
  int _pendingReportsCount = 0;
  int _inProgressReportsCount = 0;
  int _totalUsersCount = 0;
  int _activeUsersCount = 0;
  int _announcementsCount = 0;
  int _recentAnnouncementsCount = 0;
  int _activeBannersCount = 0;
  int _totalBannerClicks = 0;

  // Customer Support Statistics - NEW
  int _totalUnreadChats = 0;
  int _activeChatSessions = 0;

  // Animation controller - NEW
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Services - NEW
  final AdminChatService _chatService = AdminChatService();

  // Consistent Color Scheme
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

    // Initialize animation controller - NEW
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadAdminData();
    _loadStatistics();
    _loadUnreadNotifications();
    _loadChatStats(); // NEW
    _animationController.forward(); // NEW
  }

  @override
  void dispose() {
    _animationController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _loadUnreadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('adminId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotifications = snapshot.docs.length;
          });
        }
      });
    }
  }

  Future<void> _loadAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _avatarUrl = doc.data()?['avatarUrl'];
        _username = doc.data()?['username'] ?? "Admin";
      });
    }
  }

  // NEW: Load chat statistics
  void _loadChatStats() {
    _chatService.getAllChatSessions().listen((snapshot) {
      int unreadCount = 0;
      int activeCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isActive = data['isActive'] as bool? ?? true;
        final messageCount = data['messageCount'] as int? ?? 0;

        if (isActive) {
          activeCount++;
          if (messageCount > 0) {
            unreadCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalUnreadChats = unreadCount;
          _activeChatSessions = activeCount;
        });
      }
    });
  }

  // NEW: Navigate to customer support
  void _navigateToCustomerSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerSupportDashboard(),
      ),
    );
  }

  Future<void> _loadStatistics() async {
    try {
      // Reports statistics
      final pendingReports = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final inProgressReports = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'in-progress')
          .count()
          .get();

      // User statistics
      final totalUsers = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();

      final activeUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      // Announcement statistics
      final announcements = await FirebaseFirestore.instance
          .collection('announcements')
          .count()
          .get();

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentAnnouncements = await FirebaseFirestore.instance
          .collection('announcements')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .count()
          .get();

      // Banner statistics
      final activeBanners = await FirebaseFirestore.instance
          .collection('ad_banners')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      // Get total clicks from all banners
      final bannersSnapshot = await FirebaseFirestore.instance
          .collection('ad_banners')
          .get();

      int totalClicks = 0;
      for (var doc in bannersSnapshot.docs) {
        final data = doc.data();
        totalClicks += (data['clicks'] ?? 0) as int;
      }

      setState(() {
        _pendingReportsCount = pendingReports.count ?? 0;
        _inProgressReportsCount = inProgressReports.count ?? 0;
        _totalUsersCount = totalUsers.count ?? 0;
        _activeUsersCount = activeUsers.count ?? 0;
        _announcementsCount = announcements.count ?? 0;
        _recentAnnouncementsCount = recentAnnouncements.count ?? 0;
        _activeBannersCount = activeBanners.count ?? 0;
        _totalBannerClicks = totalClicks;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required LinearGradient gradient,
    VoidCallback? onTap,
    bool showNotification = false, // NEW: For chat notifications
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
            gradient: gradient,
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack( // NEW: Add stack for notification badge
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      if (showNotification && _totalUnreadChats > 0) // NEW: Notification badge
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: _white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, color: _white.withValues(alpha: 0.8), size: 14),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _white,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _white.withValues(alpha: 0.9),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _white.withValues(alpha: 0.7),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool showBadge = false, // NEW: For support notifications
    int badgeCount = 0, // NEW
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: _white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Stack( // NEW: Add stack for badge
        children: [
          Column(
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          if (showBadge && badgeCount > 0) // NEW: Badge for support
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _white, width: 1),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Admin Dashboard', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
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
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStatistics();
          },
          color: _darkPurple,
          child: FadeTransition( // NEW: Add fade animation
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: _lightPurple,
                          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _avatarUrl == null
                              ? Icon(Icons.admin_panel_settings, size: 35, color: _mediumPurple)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(fontSize: 14, color: _greyText),
                              ),
                              Text(
                                _username ?? 'Administrator',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _darkPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _lightPurple,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.notifications_outlined, color: _darkPurple),
                              ),
                              if (_unreadNotifications > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      _unreadNotifications > 99 ? '99+' : _unreadNotifications.toString(),
                                      style: TextStyle(
                                        color: _white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Statistics Grid - UPDATED to include customer support
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _buildStatCard(
                        title: 'Pending Reports',
                        value: _pendingReportsCount.toString(),
                        subtitle: '$_inProgressReportsCount in progress',
                        icon: Icons.report_problem,
                        iconColor: _white,
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.deepOrange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => Navigator.pushNamed(context, '/admin/reports'),
                      ),
                      _buildStatCard(
                        title: 'Total Users',
                        value: _totalUsersCount.toString(),
                        subtitle: '$_activeUsersCount active',
                        icon: Icons.people,
                        iconColor: _white,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => Navigator.pushNamed(context, '/admin/users'),
                      ),
                      _buildStatCard(
                        title: 'Announcements',
                        value: _announcementsCount.toString(),
                        subtitle: '$_recentAnnouncementsCount this week',
                        icon: Icons.campaign,
                        iconColor: _white,
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => Navigator.pushNamed(context, '/admin/announcements/manage'),
                      ),
                      _buildStatCard(
                        title: 'Ad Banners',
                        value: _activeBannersCount.toString(),
                        subtitle: '$_totalBannerClicks total clicks',
                        icon: Icons.ad_units,
                        iconColor: _white,
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BannerManagementScreen(),
                            ),
                          );
                        },
                      ),
                      // NEW: Customer Support stat card
                      _buildStatCard(
                        title: 'Customer Support',
                        value: _activeChatSessions.toString(),
                        subtitle: _totalUnreadChats > 0
                            ? '$_totalUnreadChats unread messages'
                            : 'All messages handled',
                        icon: Icons.support_agent,
                        iconColor: _white,
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade400, Colors.indigo.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: _navigateToCustomerSupport,
                        showNotification: _totalUnreadChats > 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions - UPDATED to include customer support
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(
                        label: 'Customer\nSupport',
                        icon: Icons.support_agent,
                        color: Colors.indigo,
                        onTap: _navigateToCustomerSupport,
                        showBadge: true,
                        badgeCount: _totalUnreadChats,
                      ),
                      _buildQuickActionButton(
                        label: 'New\nBanner',
                        icon: Icons.ad_units,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BannerManagementScreen(),
                            ),
                          );
                        },
                      ),
                      _buildQuickActionButton(
                        label: 'View\nReports',
                        icon: Icons.description,
                        color: Colors.orange,
                        onTap: () => Navigator.pushNamed(context, '/admin/reports'),
                      ),
                      _buildQuickActionButton(
                        label: 'User\nManage',
                        icon: Icons.group,
                        color: Colors.blue,
                        onTap: () => Navigator.pushNamed(context, '/admin/users'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 0),
    );
  }
}

// NEW: Customer Support Dashboard from admin_screen2.dart
class CustomerSupportDashboard extends StatefulWidget {
  @override
  State<CustomerSupportDashboard> createState() => _CustomerSupportDashboardState();
}

class _CustomerSupportDashboardState extends State<CustomerSupportDashboard> {
  final AdminChatService _chatService = AdminChatService();

  // Color scheme consistent with your app
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support'),
        backgroundColor: _darkPurple,
        foregroundColor: _white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Refresh the stream
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_lightPurple, _lightBeige],
          ),
        ),
        child: Column(
          children: [
            // Dashboard header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.support_agent, color: _mediumPurple, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Customer Support Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                  Text(
                    'Manage and respond to user support requests',
                    style: TextStyle(color: _greyText, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Chat sessions list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getAllChatSessions(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading chat sessions',
                            style: TextStyle(color: Colors.red),
                          ),
                          Text(
                            '${snapshot.error}',
                            style: TextStyle(color: _greyText, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: _mediumPurple),
                    );
                  }

                  final chatSessions = snapshot.data!.docs;

                  if (chatSessions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: _greyText, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'No support requests yet',
                            style: TextStyle(
                              color: _greyText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'User support chats will appear here',
                            style: TextStyle(color: _greyText),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chatSessions.length,
                    itemBuilder: (context, index) {
                      final chatDoc = chatSessions[index];
                      final chatData = chatDoc.data() as Map<String, dynamic>;

                      return _buildChatSessionCard(chatDoc.id, chatData);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSessionCard(String chatId, Map<String, dynamic> chatData) {
    final userEmail = chatData['userEmail'] as String? ?? 'Unknown User';
    final userName = userEmail.split('@')[0]; // Extract username from email
    final isActive = chatData['isActive'] as bool? ?? true;
    final messageCount = chatData['messageCount'] as int? ?? 0;
    final createdAt = chatData['createdAt'] as Timestamp?;

    // Format last message time
    String timeStr = '';
    if (createdAt != null) {
      final time = createdAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays > 0) {
        timeStr = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeStr = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeStr = '${difference.inMinutes}m ago';
      } else {
        timeStr = 'Just now';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openChatSession(chatId, chatData),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isActive ? Colors.green : Colors.grey,
                radius: 20,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: _white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _darkPurple,
                            ),
                          ),
                        ),
                        if (messageCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$messageCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (userEmail.isNotEmpty)
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: _greyText,
                        ),
                      ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: _greyText,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'RESOLVED',
                  style: TextStyle(
                    color: isActive ? Colors.green.shade700 : _greyText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigate to AdminChatScreen
  void _openChatSession(String chatId, Map<String, dynamic> chatData) {
    // Add userName to chatData if it doesn't exist
    final updatedChatData = Map<String, dynamic>.from(chatData);
    if (!updatedChatData.containsKey('userName')) {
      final userEmail = chatData['userEmail'] as String? ?? 'Unknown';
      updatedChatData['userName'] = userEmail.split('@')[0];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminChatScreen(
          chatId: chatId,
          chatData: updatedChatData,
        ),
      ),
    );
  }
}