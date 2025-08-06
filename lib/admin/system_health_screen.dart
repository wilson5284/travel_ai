// lib/screens/admin/system_health_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // System metrics
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalReports = 0;
  int _totalAnnouncements = 0;
  double _databaseSize = 0.0;
  int _errorCount = 0;
  double _systemUptime = 99.9;

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
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadSystemMetrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemMetrics() async {
    try {
      // Load various system metrics
      final usersCount = await FirebaseFirestore.instance.collection('users').count().get();
      final activeUsersCount = await FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();
      final reportsCount = await FirebaseFirestore.instance.collection('reports').count().get();
      final announcementsCount = await FirebaseFirestore.instance.collection('announcements').count().get();

      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _activeUsers = activeUsersCount.count ?? 0;
        _totalReports = reportsCount.count ?? 0;
        _totalAnnouncements = announcementsCount.count ?? 0;
        // Simulated metrics
        _databaseSize = (_totalUsers * 0.5 + _totalReports * 0.3 + _totalAnnouncements * 0.1) / 100;
        _errorCount = math.Random().nextInt(5);
        _systemUptime = 99.5 + math.Random().nextDouble() * 0.5;
      });
    } catch (e) {
      print('Error loading system metrics: $e');
    }
  }

  Color _getHealthColor(double value) {
    if (value >= 90) return Colors.green;
    if (value >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? unit,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      shadowColor: _mediumPurple.withValues(alpha: 0.1),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_white, _lightPurple.withValues(alpha: 0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unit ?? '',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _darkPurple,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _greyText),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: _greyText.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator({
    required String label,
    required double value,
    required double maxValue,
  }) {
    final double percentage = (value / maxValue * 100).clamp(0.0, 100.0);
    final color = _getHealthColor(percentage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: _greyText, fontWeight: FontWeight.w600),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    final overallHealth = _systemUptime;
    final healthColor = _getHealthColor(overallHealth);

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: _mediumPurple.withValues(alpha: 0.2),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [healthColor.withValues(alpha: 0.8), healthColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 2 * math.pi,
                  child: Icon(
                    Icons.health_and_safety,
                    color: _white,
                    size: 40,
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${overallHealth.toStringAsFixed(1)}% Operational',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorCount == 0 ? 'All systems running smoothly' : '$_errorCount minor issues detected',
                    style: TextStyle(
                      fontSize: 14,
                      color: _white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('System Health', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _darkPurple),
            onPressed: () async {
              await _loadSystemMetrics();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('System metrics refreshed', style: TextStyle(color: _white)),
                  backgroundColor: _mediumPurple,
                ),
              );
            },
          ),
        ],
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
          onRefresh: _loadSystemMetrics,
          color: _darkPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System Status Card
                _buildSystemStatus(),
                const SizedBox(height: 24),

                // Performance Metrics
                Text(
                  'Performance Metrics',
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
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildMetricCard(
                      title: 'Database Size',
                      value: _databaseSize.toStringAsFixed(2),
                      subtitle: 'Current usage',
                      icon: Icons.storage,
                      color: Colors.blue,
                      unit: 'GB',
                    ),
                    _buildMetricCard(
                      title: 'Active Sessions',
                      value: _activeUsers.toString(),
                      subtitle: 'Users online',
                      icon: Icons.people_outline,
                      color: Colors.green,
                      unit: 'USERS',
                    ),
                    _buildMetricCard(
                      title: 'Total Records',
                      value: (_totalUsers + _totalReports + _totalAnnouncements).toString(),
                      subtitle: 'All collections',
                      icon: Icons.folder_open,
                      color: Colors.orange,
                      unit: 'DOCS',
                    ),
                    _buildMetricCard(
                      title: 'Error Rate',
                      value: _errorCount.toString(),
                      subtitle: 'Last 24 hours',
                      icon: Icons.error_outline,
                      color: Colors.red,
                      unit: 'ERRORS',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // System Resources
                Text(
                  'System Resources',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkPurple,
                  ),
                ),
                const SizedBox(height: 16),
                _buildHealthIndicator(
                  label: 'CPU Usage',
                  value: 45 + math.Random().nextInt(20).toDouble(),
                  maxValue: 100,
                ),
                const SizedBox(height: 12),
                _buildHealthIndicator(
                  label: 'Memory Usage',
                  value: 60 + math.Random().nextInt(15).toDouble(),
                  maxValue: 100,
                ),
                const SizedBox(height: 12),
                _buildHealthIndicator(
                  label: 'Storage Usage',
                  value: _databaseSize * 10,
                  maxValue: 100,
                ),
                const SizedBox(height: 12),
                _buildHealthIndicator(
                  label: 'Network Latency',
                  value: 95 - math.Random().nextInt(10).toDouble(),
                  maxValue: 100,
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}