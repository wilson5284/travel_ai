// lib/screens/admin/admin_notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_report':
        return Icons.report_problem;
      case 'new_user':
        return Icons.person_add;
      case 'system_alert':
        return Icons.warning_amber;
      case 'announcement_update':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_report':
        return Colors.orange;
      case 'new_user':
        return Colors.blue;
      case 'system_alert':
        return Colors.red;
      case 'announcement_update':
        return Colors.green;
      default:
        return _mediumPurple;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('admin_notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
      'readAt': Timestamp.now(),
    });
  }

  Future<void> _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final notifications = await FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('adminId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': Timestamp.now(),
      });
    }

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All notifications marked as read', style: TextStyle(color: _white)),
        backgroundColor: _mediumPurple,
      ),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('admin_notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark all read',
              style: TextStyle(color: _mediumPurple, fontWeight: FontWeight.bold),
            ),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('admin_notifications')
              .where('adminId', isEqualTo: _currentUserId)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _darkPurple));
            }

            final notifications = snapshot.data?.docs ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(fontSize: 18, color: _greyText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll see admin alerts here',
                      style: TextStyle(fontSize: 14, color: _greyText.withOpacity(0.7)),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final data = notification.data() as Map<String, dynamic>;
                final type = data['type'] ?? 'general';
                final title = data['title'] ?? 'Notification';
                final message = data['message'] ?? '';
                final isRead = data['isRead'] ?? false;
                final timestamp = data['createdAt'];
                final actionRoute = data['actionRoute'];

                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: _white),
                  ),
                  onDismissed: (_) => _deleteNotification(notification.id),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    elevation: isRead ? 1 : 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isRead
                              ? [_white, _lightPurple.withOpacity(0.1)]
                              : [_white, _lightPurple.withOpacity(0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRead ? Colors.transparent : _mediumPurple.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            if (!isRead) {
                              await _markAsRead(notification.id);
                            }
                            if (actionRoute != null) {
                              Navigator.pushNamed(context, actionRoute);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(type).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(type),
                                    color: _getNotificationColor(type),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                color: _darkPurple,
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: _mediumPurple,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _greyText,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDateTime(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _greyText.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (actionRoute != null)
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: _mediumPurple.withOpacity(0.5),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}