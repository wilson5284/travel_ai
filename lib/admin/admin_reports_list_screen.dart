// lib/screens/admin/admin_reports_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/admin_bottom_nav_bar.dart';
import 'report_management_screen.dart';

class AdminReportsListScreen extends StatefulWidget {
  const AdminReportsListScreen({super.key});

  @override
  State<AdminReportsListScreen> createState() => _AdminReportsListScreenState();
}

class _AdminReportsListScreenState extends State<AdminReportsListScreen> {
  String _filterStatus = 'all';
  String _searchQuery = '';

  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in-progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'in-progress':
        return Icons.autorenew;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.lock;
      default:
        return Icons.help;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Method to filter documents locally (for both status and search)
  List<QueryDocumentSnapshot> _filterDocuments(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final subject = (data['subject'] ?? '').toString().toLowerCase();
      final message = (data['message'] ?? '').toString().toLowerCase();

      // Apply status filter
      bool statusMatch = _filterStatus == 'all' || status == _filterStatus.toLowerCase();

      // Apply search filter
      bool searchMatch = _searchQuery.isEmpty ||
          email.contains(_searchQuery.toLowerCase()) ||
          subject.contains(_searchQuery.toLowerCase()) ||
          message.contains(_searchQuery.toLowerCase());

      return statusMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Always get all reports and filter locally for better performance with search + status filter
    final reportsQuery = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('lastUpdated', descending: true);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('User Reports', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              Container(
                color: Colors.grey.shade200,
                height: 1.0,
              ),
              Container(
                color: _white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search by email or subject...',
                        hintStyle: TextStyle(color: _greyText),
                        prefixIcon: Icon(Icons.search, color: _darkPurple),
                        filled: true,
                        fillColor: _lightPurple.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending', 'pending'),
                          const SizedBox(width: 8),
                          _buildFilterChip('In Progress', 'in-progress'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Resolved', 'resolved'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Closed', 'closed'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        child: StreamBuilder<QuerySnapshot>(
          stream: reportsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _darkPurple));
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading reports: ${snapshot.error}',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];

            if (allDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.report_off, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No reports found.',
                      style: TextStyle(fontSize: 18, color: _greyText),
                    ),
                  ],
                ),
              );
            }

            // Apply filters
            final filteredDocs = _filterDocuments(allDocs);

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.filter_list_off,
                        size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No reports match your search.'
                          : _filterStatus == 'all'
                          ? 'No reports found.'
                          : 'No ${_filterStatus} reports found.',
                      style: TextStyle(fontSize: 18, color: _greyText),
                    ),
                    if (_searchQuery.isNotEmpty || _filterStatus != 'all') ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterStatus = 'all';
                          });
                        },
                        child: Text(
                          'Clear filters',
                          style: TextStyle(color: _mediumPurple),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Filter results summary
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Showing ${filteredDocs.length} of ${allDocs.length} reports',
                    style: TextStyle(
                      color: _greyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Reports list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final reportId = doc.id;
                      final email = data['email'] ?? 'Unknown';
                      final subject = data['subject'] ?? 'No subject';
                      final message = data['message'] ?? '';
                      final status = data['status'] ?? 'pending';
                      final timestamp = data['lastUpdated'] ?? data['timestamp'];
                      final messages = (data['messages'] as List?)?.length ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
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
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(15),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportManagementScreen(reportId: reportId),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subject,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _darkPurple,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildStatusChip(status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.email, size: 14, color: _greyText),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            email,
                                            style: TextStyle(fontSize: 13, color: _greyText),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      message,
                                      style: TextStyle(fontSize: 14, color: _greyText),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: _greyText),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDateTime(timestamp),
                                              style: TextStyle(fontSize: 12, color: _greyText),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.message, size: 14, color: _greyText),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$messages messages',
                                              style: TextStyle(fontSize: 12, color: _greyText),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_ios, size: 14, color: _mediumPurple),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _filterStatus == value;
    final Color chipColor = value == 'all' ? _darkPurple : _getStatusColor(value);

    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: value == 'all'
                ? [_mediumPurple, _darkPurple]
                : [chipColor.withValues(alpha: 0.8), chipColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : chipColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _white : chipColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}