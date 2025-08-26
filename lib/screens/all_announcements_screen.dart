import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AllAnnouncementsScreen extends StatefulWidget {
  const AllAnnouncementsScreen({super.key});

  @override
  State<AllAnnouncementsScreen> createState() => _AllAnnouncementsScreenState();
}

class _AllAnnouncementsScreenState extends State<AllAnnouncementsScreen> {
  bool _isDescending = true;
  String _filterPriority = 'all';
  String _searchQuery = '';
  List<String> _readAnnouncements = [];

  // Consistent Color Scheme matching admin
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
    _loadUserReadAnnouncements();
  }

  Future<void> _loadUserReadAnnouncements() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _readAnnouncements = List<String>.from(userData['readAnnouncements'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading user read announcements: $e');
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.drag_handle;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildPriorityChip(String priority) {
    final color = _getPriorityColor(priority);
    final icon = _getPriorityIcon(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final bool isSelected = _filterPriority == value;

    return GestureDetector(
      onTap: () => setState(() => _filterPriority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [color.withValues(alpha: 0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _white : color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterAnnouncements(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final message = (data['message'] ?? '').toString().toLowerCase();
      final priority = (data['priority'] ?? 'medium').toString().toLowerCase();
      final isActive = data['isActive'] ?? true;

      // Only show active announcements to users
      if (!isActive) return false;

      // Apply search filter
      bool searchMatch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          message.contains(_searchQuery.toLowerCase());

      // Apply priority filter
      bool priorityMatch = _filterPriority == 'all' || priority == _filterPriority.toLowerCase();

      return searchMatch && priorityMatch;
    }).toList();
  }

  Future<void> _incrementViewCount(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(docId)
          .update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      // Silently handle error - view count is not critical
    }
  }

  Future<void> _markAnnouncementAsRead(String docId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Skip if already read
    if (_readAnnouncements.contains(docId)) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'readAnnouncements': FieldValue.arrayUnion([docId]),
      });

      // Update local state
      setState(() {
        _readAnnouncements.add(docId);
      });
    } catch (e) {
      print('Error marking announcement as read: $e');
    }
  }

  void _showAnnouncementDetail(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final message = data['message'] ?? '';
    final priority = data['priority'] ?? 'medium';
    final authorName = data['authorName'] ?? 'Admin';
    final timestamp = data['createdAt'];

    // Increment view count and mark as read when user opens detail
    _incrementViewCount(doc.id);
    _markAnnouncementAsRead(doc.id);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_mediumPurple, _darkPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.campaign, color: _white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: _darkPurple,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildPriorityChip(priority),
                            const SizedBox(width: 8),
                            Text(
                              'by $authorName',
                              style: TextStyle(color: _greyText, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: _greyText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_lightPurple.withValues(alpha: 0.3), _white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _lightPurple, width: 1),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 16,
                            color: _greyText,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Footer info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _offWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: _greyText),
                            const SizedBox(width: 8),
                            Text(
                              'Posted ${_formatDateTime(timestamp)}',
                              style: TextStyle(color: _greyText, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Close button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_mediumPurple, _darkPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _mediumPurple.withValues(alpha: 0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, color: _white),
                          const SizedBox(width: 8),
                          Text(
                            'Got it!',
                            style: TextStyle(
                              color: _white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isAnnouncementRead(String docId) {
    return _readAnnouncements.contains(docId);
  }

  @override
  Widget build(BuildContext context) {
    final announcementsRef = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: _isDescending);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Announcements',
          style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isDescending ? Icons.arrow_downward : Icons.arrow_upward,
              color: _darkPurple,
            ),
            tooltip: 'Sort by date',
            onPressed: () => setState(() => _isDescending = !_isDescending),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
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
                        hintText: 'Search announcements...',
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
                          _buildFilterChip('All', 'all', _darkPurple),
                          const SizedBox(width: 8),
                          _buildFilterChip('High', 'high', Colors.red),
                          const SizedBox(width: 8),
                          _buildFilterChip('Medium', 'medium', Colors.orange),
                          const SizedBox(width: 8),
                          _buildFilterChip('Low', 'low', Colors.green),
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
          stream: announcementsRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _darkPurple));
            }

            final allDocs = snapshot.data?.docs ?? [];
            final filteredDocs = _filterAnnouncements(allDocs);

            if (allDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No announcements yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for updates!',
                      style: TextStyle(fontSize: 16, color: _greyText),
                    ),
                  ],
                ),
              );
            }

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No announcements match your search',
                      style: TextStyle(fontSize: 18, color: _greyText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _filterPriority = 'all';
                        });
                      },
                      child: Text('Clear filters', style: TextStyle(color: _mediumPurple)),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Results summary
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _mediumPurple.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: _greyText),
                      const SizedBox(width: 8),
                      Text(
                        '${filteredDocs.length} announcement${filteredDocs.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: _greyText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isRead = _isAnnouncementRead(doc.id);

                      final title = data['title'] ?? 'Untitled';
                      final message = data['message'] ?? '';
                      final priority = data['priority'] ?? 'medium';
                      final authorName = data['authorName'] ?? 'Admin';
                      final timestamp = data['createdAt'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        shadowColor: _mediumPurple.withValues(alpha: 0.15),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isRead
                                  ? [_offWhite, _lightPurple.withValues(alpha: 0.2)] // Dimmer for read announcements
                                  : [_white, _lightPurple.withValues(alpha: 0.3)], // Brighter for unread
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: !isRead ? Border.all(
                              color: _mediumPurple.withValues(alpha: 0.3),
                              width: 2,
                            ) : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showAnnouncementDetail(doc),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [_mediumPurple, _darkPurple],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.campaign, color: _white, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: isRead ? _greyText : _darkPurple,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        _buildPriorityChip(priority),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Message Preview
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _white.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _lightPurple.withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _greyText,
                                          height: 1.5,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Footer Row
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 16, color: _greyText),
                                        const SizedBox(width: 4),
                                        Text(
                                          authorName,
                                          style: TextStyle(
                                            color: _greyText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.access_time, size: 16, color: _greyText),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDateTime(timestamp),
                                          style: TextStyle(color: _greyText, fontSize: 13),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [_mediumPurple.withValues(alpha: 0.1), _darkPurple.withValues(alpha: 0.1)],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.touch_app, size: 12, color: _mediumPurple),
                                              const SizedBox(width: 4),
                                              Text(
                                                isRead ? 'READ' : 'TAP TO READ',
                                                style: TextStyle(
                                                  color: _mediumPurple,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
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
    );
  }
}