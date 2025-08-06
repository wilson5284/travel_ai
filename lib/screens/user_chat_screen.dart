import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_chat_service.dart';

class UserChatScreen extends StatefulWidget {
  const UserChatScreen({super.key});

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AdminChatService _chatService = AdminChatService();

  String? _chatId;
  bool _isLoading = true;
  bool _isSending = false;

  // Color scheme (consistent with your app)
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
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      final chatId = await _chatService.createOrGetChatSession();
      setState(() {
        _chatId = chatId;
        _isLoading = false;
      });

      // Mark messages as read when opening chat
      if (chatId != null) {
        await _chatService.markMessagesAsReadByUser(chatId);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatId == null || _isSending) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      await _chatService.sendUserMessage(_chatId!, message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        backgroundColor: _darkPurple,
        foregroundColor: _white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: _white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: Text('Support Chat', style: TextStyle(color: _darkPurple)),
                  content: Text(
                    'You\'re connected to our support team. We\'ll respond as soon as possible!',
                    style: TextStyle(color: _greyText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Got it', style: TextStyle(color: _mediumPurple)),
                    ),
                  ],
                ),
              );
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
            // Welcome message
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _mediumPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _mediumPurple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.support_agent, color: _mediumPurple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Support Chat!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _darkPurple,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Our team will respond to your message shortly.',
                          style: TextStyle(color: _greyText, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages area
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(color: _mediumPurple),
              )
                  : _chatId == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to initialize chat',
                      style: TextStyle(color: Colors.red, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initializeChat,
                      style: ElevatedButton.styleFrom(backgroundColor: _mediumPurple),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
                  : StreamBuilder<QuerySnapshot>(
                stream: _chatService.getChatMessages(_chatId!),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text('Error loading messages', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: _mediumPurple));
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: _greyText, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Start the conversation!',
                            style: TextStyle(
                              color: _greyText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Send a message to get help from our support team.',
                            style: TextStyle(color: _greyText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Auto-scroll to bottom when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageDoc = messages[index];
                      final messageData = messageDoc.data() as Map<String, dynamic>;
                      return _buildMessageBubble(messageData);
                    },
                  );
                },
              ),
            ),

            // Message input area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: _greyText),
                        filled: true,
                        fillColor: _lightBeige.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: _mediumPurple.withOpacity(0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: _mediumPurple.withOpacity(0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: _darkPurple, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      style: TextStyle(color: _darkPurple),
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_mediumPurple, _darkPurple],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _mediumPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _white,
                          strokeWidth: 2,
                        ),
                      )
                          : Icon(Icons.send, color: _white),
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

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final senderType = messageData['senderType'] as String;
    final message = messageData['message'] as String;
    final timestamp = messageData['timestamp'] as Timestamp?;
    final isFromUser = senderType == 'user';

    // Format timestamp
    String timeStr = '';
    if (timestamp != null) {
      final time = timestamp.toDate();
      timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    return Align(
      alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isFromUser)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Support Team',
                  style: TextStyle(
                    fontSize: 12,
                    color: _greyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isFromUser
                    ? LinearGradient(colors: [_mediumPurple, _darkPurple])
                    : null,
                color: isFromUser ? null : _white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isFromUser ? const Radius.circular(4) : null,
                  bottomLeft: isFromUser ? null : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isFromUser ? null : Border.all(color: _mediumPurple.withOpacity(0.2)),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isFromUser ? _white : _darkPurple,
                  fontSize: 16,
                ),
              ),
            ),
            if (timeStr.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: isFromUser ? 0 : 12,
                  right: isFromUser ? 12 : 0,
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: _greyText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}