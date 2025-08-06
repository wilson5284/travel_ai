// lib/services/admin_chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create or get existing chat session
  Future<String> createOrGetChatSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user already has a chat session
      final existingChat = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingChat.docs.isNotEmpty) {
        return existingChat.docs.first.id;
      }

      // Create new chat session
      final chatDoc = await _firestore.collection('chat_sessions').add({
        'userId': user.uid,
        'userEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'messageCount': 0,
      });

      return chatDoc.id;
    } catch (e) {
      throw Exception('Failed to create chat session: $e');
    }
  }

  // Check if current user is admin
  Future<bool> isUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['isAdmin'] == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get all chat sessions (for admin view)
  Stream<QuerySnapshot> getAllChatSessions() {
    return _firestore
        .collection('chat_sessions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Send message in chat (Admin version)
  Future<void> sendMessage(String chatId, String message, bool isFromAdmin) async {
    try {
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .collection('messages')
          .add({
        'message': message,
        'senderType': isFromAdmin ? 'admin' : 'user',
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _auth.currentUser?.uid,
      });

      // Update message count
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .update({
        'messageCount': FieldValue.increment(1),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Send user message (for UserChatScreen)
  Future<void> sendUserMessage(String chatId, String message) async {
    try {
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .collection('messages')
          .add({
        'message': message,
        'senderType': 'user',
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _auth.currentUser?.uid,
      });

      // Update message count
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .update({
        'messageCount': FieldValue.increment(1),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages for a chat session
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chat_sessions')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get chat messages (alternative method name for consistency)
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return getMessages(chatId);
  }

  // Mark chat as resolved
  Future<void> resolveChatSession(String chatId) async {
    try {
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .update({
        'isActive': false,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to resolve chat: $e');
    }
  }

  // Mark messages as read by admin
  Future<void> markMessagesAsReadByAdmin(String chatId) async {
    try {
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .update({
        'unreadByAdmin': 0,
      });
    } catch (e) {
      print('Error marking messages as read by admin: $e');
    }
  }

  // Mark messages as read by user
  Future<void> markMessagesAsReadByUser(String chatId) async {
    try {
      await _firestore
          .collection('chat_sessions')
          .doc(chatId)
          .update({
        'unreadByUser': 0,
      });
    } catch (e) {
      print('Error marking messages as read by user: $e');
    }
  }
}