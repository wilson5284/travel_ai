// lib/screens/admin_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/admin_chat_service.dart';
import '../screens/admin_chat_screen.dart'; // Add this import for the individual chat screen

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  String? _photoUrl;
  String? _username;
  bool _isLoading = true;
  int _totalUnreadChats = 0;
  int _activeChatSessions = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AdminChatService _chatService = AdminChatService();

  // Enhanced color scheme consistent with your app
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadAdminData();
    _loadChatStats();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        setState(() {
          _photoUrl = doc.data()?['photoUrl'];
          _username = doc.data()?['username'] ?? "Admin";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading admin data: $e');
    }
  }

  void _loadChatStats() {
    // Listen to chat statistics in real-time
    _chatService.getAllChatSessions().listen((snapshot) {
      int unreadCount = 0;
      int activeCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isActive = data['isActive'] as bool? ?? true;
        final messageCount = data['messageCount'] as int? ?? 0;

        if (isActive) {
          activeCount++;
          // For simplicity, we'll count sessions with messages as having unread content
          // You can implement a more sophisticated unread message system
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

  void _navigateToCustomerSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerSupportDashboard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lightPurple,
              _lightBeige,
              _white,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Enhanced Header Section
                  _buildHeaderSection(),
                  const SizedBox(height: 32),

                  // Statistics Cards
                  _buildStatsSection(),
                  const SizedBox(height: 32),

                  // Main Admin Tools
                  _buildAdminToolsSection(),
                  const SizedBox(height: 32),

                  // Logout Section
                  _buildLogoutSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkPurple, _mediumPurple],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _mediumPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with loading state
          _isLoading
              ? Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _white.withOpacity(0.3),
            ),
            child: Center(
              child: CircularProgressIndicator(color: _white),
            ),
          )
              : Hero(
            tag: 'admin_avatar',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                backgroundColor: _white,
                child: _photoUrl == null
                    ? Icon(Icons.admin_panel_settings, size: 40, color: _mediumPurple)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Welcome text
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 16,
              color: _white.withOpacity(0.9),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _username ?? 'Admin Panel',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Administrator',
              style: TextStyle(
                fontSize: 14,
                color: _white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.chat_bubble_outline,
            title: 'Active Chats',
            value: '$_activeChatSessions',
            color: Colors.blue,
            iconColor: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.notifications_active,
            title: 'Unread Messages',
            value: '$_totalUnreadChats',
            color: Colors.orange,
            iconColor: Colors.orange.shade700,
            showBadge: _totalUnreadChats > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color iconColor,
    bool showBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              if (showBadge)
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
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkPurple,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: _greyText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administration Tools',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _darkPurple,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your application and users',
          style: TextStyle(
            fontSize: 14,
            color: _greyText,
          ),
        ),
        const SizedBox(height: 20),

        // Customer Support - Featured Tool
        _buildFeaturedAdminTool(
          icon: Icons.support_agent,
          title: "Customer Support",
          subtitle: _totalUnreadChats > 0
              ? "$_totalUnreadChats unread messages"
              : "All messages handled",
          color: Colors.green,
          onTap: _navigateToCustomerSupport,
          showNotification: _totalUnreadChats > 0,
        ),

        const SizedBox(height: 16),

        // Other Admin Tools
        _buildAdminTool(
          icon: Icons.report_outlined,
          title: "Manage User Reports",
          subtitle: "Review and handle user reports",
          color: Colors.deepOrange,
          onTap: () {
            // Navigate to user reports screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User Reports feature coming soon!')),
            );
          },
        ),

        _buildAdminTool(
          icon: Icons.people_outline,
          title: "Manage Users",
          subtitle: "View and manage user accounts",
          color: Colors.blue,
          onTap: () {
            // Navigate to user management screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User Management feature coming soon!')),
            );
          },
        ),

        _buildAdminTool(
          icon: Icons.announcement_outlined,
          title: "Manage Announcements",
          subtitle: "Create and edit announcements",
          color: Colors.indigo,
          onTap: () {
            // Navigate to announcements screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Announcements feature coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedAdminTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool showNotification = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: _white, size: 28),
                    ),
                    if (showNotification)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _white, width: 2),
                          ),
                          child: Text(
                            '$_totalUnreadChats',
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
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: _white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _white.withOpacity(0.8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _darkPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: _greyText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _greyText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.logout, color: Colors.red.shade700, size: 32),
          const SizedBox(height: 12),
          Text(
            'Session Management',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Securely end your admin session',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: _white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Confirm Logout', style: TextStyle(color: _darkPurple)),
                    content: const Text('Are you sure you want to end your admin session?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Cancel', style: TextStyle(color: _greyText)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text("End Admin Session", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: _white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Customer Support Dashboard
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

  // Updated method to navigate to AdminChatScreen
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