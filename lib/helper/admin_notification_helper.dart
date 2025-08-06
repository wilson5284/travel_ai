// lib/helpers/admin_notification_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create notification when a new report is submitted
  static Future<void> notifyNewReport({
    required String adminId,
    required String reportId,
    required String reportSubject,
    required String userEmail,
  }) async {
    await _firestore.collection('admin_notifications').add({
      'adminId': adminId,
      'type': 'new_report',
      'title': 'New Report Submitted',
      'message': '$userEmail submitted: "$reportSubject"',
      'actionRoute': '/admin/reports',
      'relatedId': reportId,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // Create notification when a new user registers
  static Future<void> notifyNewUser({
    required String adminId,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    await _firestore.collection('admin_notifications').add({
      'adminId': adminId,
      'type': 'new_user',
      'title': 'New User Registration',
      'message': '$userName ($userEmail) just signed up',
      'actionRoute': '/admin/users',
      'relatedId': userId,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // Create system alert notification
  static Future<void> notifySystemAlert({
    required String adminId,
    required String alertTitle,
    required String alertMessage,
  }) async {
    await _firestore.collection('admin_notifications').add({
      'adminId': adminId,
      'type': 'system_alert',
      'title': alertTitle,
      'message': alertMessage,
      'actionRoute': '/admin/system-health',
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // Create announcement update notification
  static Future<void> notifyAnnouncementUpdate({
    required String adminId,
    required String announcementId,
    required String action, // 'created', 'updated', 'deleted'
    required String announcementTitle,
  }) async {
    final actionText = action == 'created' ? 'New announcement posted'
        : action == 'updated' ? 'Announcement updated'
        : 'Announcement deleted';

    await _firestore.collection('admin_notifications').add({
      'adminId': adminId,
      'type': 'announcement_update',
      'title': actionText,
      'message': 'Announcement: "$announcementTitle"',
      'actionRoute': '/admin/announcements/manage',
      'relatedId': announcementId,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // Notify all admins
  static Future<void> notifyAllAdmins({
    required String type,
    required String title,
    required String message,
    String? actionRoute,
    String? relatedId,
  }) async {
    // Get all admin users
    final admins = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    // Create notification for each admin
    final batch = _firestore.batch();

    for (var admin in admins.docs) {
      final notificationRef = _firestore.collection('admin_notifications').doc();
      batch.set(notificationRef, {
        'adminId': admin.id,
        'type': type,
        'title': title,
        'message': message,
        'actionRoute': actionRoute,
        'relatedId': relatedId,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    }

    await batch.commit();
  }

  // Clean up old notifications (older than 30 days)
  static Future<void> cleanupOldNotifications() async {
    final thirtyDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30))
    );

    final oldNotifications = await _firestore
        .collection('admin_notifications')
        .where('createdAt', isLessThan: thirtyDaysAgo)
        .get();

    final batch = _firestore.batch();
    for (var doc in oldNotifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}