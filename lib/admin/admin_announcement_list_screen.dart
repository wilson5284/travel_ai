// lib/screens/admin/admin_announcement_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/admin_bottom_nav_bar.dart';

class AdminAnnouncementListScreen extends StatefulWidget {
  const AdminAnnouncementListScreen({super.key});

  @override
  State<AdminAnnouncementListScreen> createState() =>
      _AdminAnnouncementListScreenState();
}

class _AdminAnnouncementListScreenState
    extends State<AdminAnnouncementListScreen> {
  bool _isDescending = true;
  String _filterPriority = 'all';
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
    if (timestamp == null) return 'Unknown';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Posted ${difference.inMinutes} min ago';
      }
      return 'Posted ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return 'Posted ${difference.inDays}d ago';
    } else {
      return 'Posted on ${dt.day}/${dt.month}/${dt.year}';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.visibility : Icons.visibility_off,
            size: 12,
            color: isActive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'ACTIVE' : 'DRAFT',
            style: TextStyle(
              color: isActive ? Colors.green : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text('Delete Announcement', style: TextStyle(color: _darkPurple, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this announcement?',
              style: TextStyle(fontSize: 16, color: _greyText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: _greyText)),
            onPressed: () => Navigator.pop(context, false),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pop(context, true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: _white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(id)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: _white),
              const SizedBox(width: 8),
              Text('Announcement deleted successfully', style: TextStyle(color: _white)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showEditDialog({
    String? id,
    String? initialTitle,
    String? initialMessage,
    String? initialPriority,
    bool? initialIsActive,
  }) async {
    final titleController = TextEditingController(text: initialTitle ?? '');
    final messageController = TextEditingController(text: initialMessage ?? '');
    String selectedPriority = initialPriority ?? 'medium';
    bool isActive = initialIsActive ?? true;
    final isNew = id == null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
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
                      child: Icon(
                        isNew ? Icons.add_circle : Icons.edit,
                        color: _white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNew ? 'Create New Announcement' : 'Edit Announcement',
                            style: TextStyle(
                              color: _darkPurple,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isNew ? 'Share important updates with users' : 'Update announcement details',
                            style: TextStyle(color: _greyText, fontSize: 14),
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

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Field
                        Text(
                          'Title *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: 'Enter announcement title...',
                            hintStyle: TextStyle(color: _greyText.withValues(alpha: 0.6)),
                            prefixIcon: Icon(Icons.title, color: _mediumPurple),
                            filled: true,
                            fillColor: _lightPurple.withValues(alpha: 0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _darkPurple, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Message Field
                        Text(
                          'Message *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Write your announcement message here...',
                            hintStyle: TextStyle(color: _greyText.withValues(alpha: 0.6)),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Icon(Icons.message, color: _mediumPurple),
                            ),
                            filled: true,
                            fillColor: _lightPurple.withValues(alpha: 0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _darkPurple, width: 2),
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Priority Section
                        Text(
                          'Priority',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _lightPurple.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<String>(
                            value: selectedPriority,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem(
                                value: 'low',
                                child: Row(
                                  children: [
                                    Icon(Icons.keyboard_arrow_down, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Low Priority'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'medium',
                                child: Row(
                                  children: [
                                    Icon(Icons.drag_handle, color: Colors.orange, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Medium Priority'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'high',
                                child: Row(
                                  children: [
                                    Icon(Icons.priority_high, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Text('High Priority'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedPriority = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Section
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _lightPurple.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => isActive = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !isActive ? Colors.grey : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Draft',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !isActive ? _white : _greyText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => isActive = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Active',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isActive ? _white : _greyText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _greyText.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: _greyText, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_mediumPurple, _darkPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _mediumPurple.withValues(alpha: 0.4),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final title = titleController.text.trim();
                              final message = messageController.text.trim();

                              if (title.isEmpty || message.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.warning, color: _white),
                                        const SizedBox(width: 8),
                                        Text('Title and message are required', style: TextStyle(color: _white)),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                return;
                              }

                              final now = Timestamp.now();
                              final currentUser = FirebaseAuth.instance.currentUser;
                              final authorName = currentUser?.displayName ?? 'Admin';

                              final ref = FirebaseFirestore.instance.collection('announcements');

                              if (isNew) {
                                await ref.add({
                                  'title': title,
                                  'message': message,
                                  'priority': selectedPriority,
                                  'isActive': isActive,
                                  'authorId': currentUser?.uid,
                                  'authorName': authorName,
                                  'createdAt': now,
                                  'latestActivity': now,
                                  'viewCount': 0,
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: _white),
                                        const SizedBox(width: 8),
                                        Text('Announcement posted successfully!', style: TextStyle(color: _white)),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              } else {
                                await ref.doc(id).update({
                                  'title': title,
                                  'message': message,
                                  'priority': selectedPriority,
                                  'isActive': isActive,
                                  'editedAt': now,
                                  'latestActivity': now,
                                  'lastEditedBy': authorName,
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: _white),
                                        const SizedBox(width: 8),
                                        Text('Announcement updated successfully!', style: TextStyle(color: _white)),
                                      ],
                                    ),
                                    backgroundColor: _mediumPurple,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }

                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isNew ? Icons.publish : Icons.save, color: _white),
                                  const SizedBox(width: 8),
                                  Text(
                                    isNew ? 'Publish Announcement' : 'Save Changes',
                                    style: TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

      // Apply search filter
      bool searchMatch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          message.contains(_searchQuery.toLowerCase());

      // Apply priority filter
      bool priorityMatch = _filterPriority == 'all' || priority == _filterPriority.toLowerCase();

      return searchMatch && priorityMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final announcementsRef = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('latestActivity', descending: _isDescending);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Manage Announcements', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward, color: _darkPurple),
            tooltip: 'Sort by date',
            onPressed: () => setState(() => _isDescending = !_isDescending),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_mediumPurple, _darkPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _mediumPurple.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: _white),
              tooltip: 'Create New Announcement',
              onPressed: () => _showEditDialog(),
            ),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkPurple),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first announcement to get started',
                      style: TextStyle(fontSize: 16, color: _greyText),
                    ),
                    const SizedBox(height: 24),
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
                            color: _mediumPurple.withValues(alpha: 0.4),
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
                          onTap: () => _showEditDialog(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle, color: _white),
                                const SizedBox(width: 8),
                                Text(
                                  'Create First Announcement',
                                  style: TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                // Filter results summary
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Showing ${filteredDocs.length} of ${allDocs.length} announcements',
                    style: TextStyle(
                      color: _greyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final id = doc.id;
                      final data = doc.data() as Map<String, dynamic>;

                      final title = data['title'] ?? 'Untitled';
                      final message = data['message'] ?? '';
                      final priority = data['priority'] ?? 'medium';
                      final isActive = data['isActive'] ?? true;
                      final authorName = data['authorName'] ?? 'Admin';
                      final viewCount = data['viewCount'] ?? 0;
                      final hasEdited = data['editedAt'] != null;
                      final timestamp = data['latestActivity'];

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
                              colors: [_white, _lightPurple.withValues(alpha: 0.4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showEditDialog(
                                id: id,
                                initialTitle: title,
                                initialMessage: message,
                                initialPriority: priority,
                                initialIsActive: isActive,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                              color: _darkPurple,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteAnnouncement(id, title),
                                            tooltip: 'Delete announcement',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Status and Priority Row
                                    Row(
                                      children: [
                                        _buildStatusChip(isActive),
                                        const SizedBox(width: 8),
                                        _buildPriorityChip(priority),
                                        const Spacer(),
                                        if (hasEdited)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit, size: 12, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'EDITED',
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Message Preview
                                    Text(
                                      message,
                                      style: TextStyle(fontSize: 16, color: _greyText, height: 1.5),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 16),

                                    // Footer Row
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 16, color: _greyText),
                                        const SizedBox(width: 4),
                                        Text(
                                          authorName,
                                          style: TextStyle(color: _greyText, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(Icons.visibility, size: 16, color: _greyText),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$viewCount views',
                                          style: TextStyle(color: _greyText, fontSize: 14),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.access_time, size: 16, color: _greyText),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDateTime(timestamp),
                                          style: TextStyle(color: _greyText, fontSize: 14),
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
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 0), // Dashboard is active
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
}