// lib/admin/banner_analytics_screen.dart - NEW FILE FOR VIEWING ANALYTICS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BannerAnalyticsScreen extends StatefulWidget {
  const BannerAnalyticsScreen({super.key});

  @override
  State<BannerAnalyticsScreen> createState() => _BannerAnalyticsScreenState();
}

class _BannerAnalyticsScreenState extends State<BannerAnalyticsScreen> {
  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  String _selectedTimeframe = '7d';
  final List<String> _timeframes = ['24h', '7d', '30d', 'all'];

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedTimeframe) {
      case '24h':
        return now.subtract(const Duration(hours: 24));
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      default:
        return DateTime(2020); // Far in the past for "all"
    }
  }

  String _getTimeframeLabel() {
    switch (_selectedTimeframe) {
      case '24h':
        return 'Last 24 Hours';
      case '7d':
        return 'Last 7 Days';
      case '30d':
        return 'Last 30 Days';
      default:
        return 'All Time';
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _darkPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _darkPurple,
              ),
            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Banner Analytics', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
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
        child: Column(
          children: [
            // Timeframe Selector
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Timeframe: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _darkPurple,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _mediumPurple.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTimeframe,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _timeframes.map((timeframe) {
                          String label;
                          switch (timeframe) {
                            case '24h':
                              label = 'Last 24 Hours';
                              break;
                            case '7d':
                              label = 'Last 7 Days';
                              break;
                            case '30d':
                              label = 'Last 30 Days';
                              break;
                            default:
                              label = 'All Time';
                          }
                          return DropdownMenuItem(
                            value: timeframe,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedTimeframe = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('banner_analytics')
                    .where('timestamp', isGreaterThan: Timestamp.fromDate(_getStartDate()))
                    .snapshots(),
                builder: (context, analyticsSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('ad_banners')
                        .snapshots(),
                    builder: (context, bannersSnapshot) {
                      if (analyticsSnapshot.connectionState == ConnectionState.waiting ||
                          bannersSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: _darkPurple));
                      }

                      final analyticsData = analyticsSnapshot.data?.docs ?? [];
                      final banners = bannersSnapshot.data?.docs ?? [];

                      // Calculate metrics
                      int totalImpressions = 0;
                      int totalClicks = 0;
                      Map<String, int> impressionsByPosition = {};
                      Map<String, int> clicksByPosition = {};
                      Map<String, Map<String, int>> bannerStats = {};

                      for (var doc in analyticsData) {
                        final data = doc.data() as Map<String, dynamic>;
                        final type = data['type'];
                        final position = data['position'] ?? 'unknown';
                        final bannerId = data['bannerId'];

                        if (type == 'impression') {
                          totalImpressions++;
                          impressionsByPosition[position] = (impressionsByPosition[position] ?? 0) + 1;
                        } else if (type == 'click') {
                          totalClicks++;
                          clicksByPosition[position] = (clicksByPosition[position] ?? 0) + 1;
                        }

                        // Track per banner
                        if (!bannerStats.containsKey(bannerId)) {
                          bannerStats[bannerId] = {'impressions': 0, 'clicks': 0};
                        }
                        if (type == 'impression') {
                          bannerStats[bannerId]!['impressions'] = bannerStats[bannerId]!['impressions']! + 1;
                        } else if (type == 'click') {
                          bannerStats[bannerId]!['clicks'] = bannerStats[bannerId]!['clicks']! + 1;
                        }
                      }

                      final clickThroughRate = totalImpressions > 0
                          ? (totalClicks / totalImpressions * 100).toStringAsFixed(2)
                          : '0.00';

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overall Metrics
                            Text(
                              'Overall Performance - ${_getTimeframeLabel()}',
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
                              childAspectRatio: 1.3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                _buildMetricCard(
                                  title: 'Total Impressions',
                                  value: totalImpressions.toString(),
                                  subtitle: 'Banner views',
                                  icon: Icons.visibility,
                                  color: Colors.blue,
                                ),
                                _buildMetricCard(
                                  title: 'Total Clicks',
                                  value: totalClicks.toString(),
                                  subtitle: 'User interactions',
                                  icon: Icons.touch_app,
                                  color: Colors.green,
                                ),
                                _buildMetricCard(
                                  title: 'Click-Through Rate',
                                  value: '$clickThroughRate%',
                                  subtitle: 'Clicks per impression',
                                  icon: Icons.trending_up,
                                  color: Colors.orange,
                                ),
                                _buildMetricCard(
                                  title: 'Active Banners',
                                  value: banners.where((b) => (b.data() as Map)['isActive'] == true).length.toString(),
                                  subtitle: 'Currently showing',
                                  icon: Icons.ad_units,
                                  color: Colors.purple,
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Performance by Position
                            Text(
                              'Performance by Position',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 16),

                            ...['top', 'middle', 'bottom'].map((position) {
                              final impressions = impressionsByPosition[position] ?? 0;
                              final clicks = clicksByPosition[position] ?? 0;
                              final ctr = impressions > 0 ? (clicks / impressions * 100).toStringAsFixed(1) : '0.0';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getPositionColor(position).withValues(alpha: 0.2),
                                    child: Icon(_getPositionIcon(position), color: _getPositionColor(position)),
                                  ),
                                  title: Text(
                                    '${position.toUpperCase()} Position',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: _darkPurple),
                                  ),
                                  subtitle: Text('$impressions views • $clicks clicks • $ctr% CTR'),
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 32),

                            // Individual Banner Performance
                            Text(
                              'Individual Banner Performance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkPurple,
                              ),
                            ),
                            const SizedBox(height: 16),

                            ...banners.map((banner) {
                              final bannerData = banner.data() as Map<String, dynamic>;
                              final title = bannerData['title'] ?? 'Untitled';
                              final position = bannerData['position'] ?? 'unknown';
                              final isActive = bannerData['isActive'] ?? false;

                              final stats = bannerStats[banner.id] ?? {'impressions': 0, 'clicks': 0};
                              final impressions = stats['impressions']!;
                              final clicks = stats['clicks']!;
                              final ctr = impressions > 0 ? (clicks / impressions * 100).toStringAsFixed(1) : '0.0';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                    child: Icon(
                                      isActive ? Icons.play_circle : Icons.pause_circle,
                                      color: isActive ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: _darkPurple),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Position: ${position.toUpperCase()}'),
                                      Text('$impressions views • $clicks clicks • $ctr% CTR'),
                                    ],
                                  ),
                                  trailing: Text(
                                    isActive ? 'ACTIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
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

  Color _getPositionColor(String position) {
    switch (position) {
      case 'top':
        return Colors.blue;
      case 'middle':
        return Colors.orange;
      case 'bottom':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getPositionIcon(String position) {
    switch (position) {
      case 'top':
        return Icons.keyboard_arrow_up;
      case 'middle':
        return Icons.drag_handle;
      case 'bottom':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.help_outline;
    }
  }
}