// lib/screens/admin_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_chat_service.dart';

class AdminChatScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> chatData;

  const AdminChatScreen({
    Key? key,
    required this.chatId,
    required this.chatData,
  }) : super(key: key);

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AdminChatService _chatService = AdminChatService();
  bool _isLoading = false;
  bool _isSending = false;

  // Color scheme consistent with your app
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
    _markMessagesAsReadByAdmin();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsReadByAdmin() async {
    try {
      await _chatService.markMessagesAsReadByAdmin(widget.chatId);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(widget.chatId, messageText, true);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
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

  Future<void> _resolveChatSession() async {
    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Resolve Chat Session', style: TextStyle(color: _darkPurple)),
        content: const Text('Are you sure you want to mark this chat as resolved?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: _greyText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (shouldResolve == true) {
      try {
        await _chatService.resolveChatSession(widget.chatId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat session resolved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resolve chat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.chatData['userName'] as String? ??
        (widget.chatData['userEmail'] as String?)?.split('@')[0] ??
        'Unknown User';
    final userEmail = widget.chatData['userEmail'] as String? ?? '';
    final isActive = widget.chatData['isActive'] as bool? ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userName, style: const TextStyle(fontSize: 16)),
            if (userEmail.isNotEmpty)
              Text(
                userEmail,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: _darkPurple,
        foregroundColor: _white,
        elevation: 0,
        actions: [
          if (isActive)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _resolveChatSession,
              tooltip: 'Resolve Chat',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'resolve':
                  _resolveChatSession();
                  break;
                case 'user_info':
                  _showUserInfo();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (isActive)
                const PopupMenuItem(
                  value: 'resolve',
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Resolve Chat'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'user_info',
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blue),
                  title: Text('User Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
            // Chat status banner
            if (!isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.shade100,
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'This chat session has been RESOLVED',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Admin info banner
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
                  Icon(Icons.admin_panel_settings, color: _mediumPurple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Support Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _darkPurple,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'You\'re responding as support team to $userName',
                          style: TextStyle(color: _greyText, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading messages',
                            style: TextStyle(color: Colors.red, fontSize: 16),
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

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: _greyText, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: _greyText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Start the conversation with $userName',
                            style: TextStyle(color: _greyText),
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

            // Message input (only show if chat is active)
            if (isActive) _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final senderType = messageData['senderType'] as String? ?? 'user';
    final message = messageData['message'] as String? ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    final isFromAdmin = senderType == 'admin';

    String timeStr = '';
    if (timestamp != null) {
      final time = timestamp.toDate();
      timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    return Align(
      alignment: isFromAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isFromAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isFromAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Text(
                  'You (Admin)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _greyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  widget.chatData['userName'] as String? ?? 'User',
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
                gradient: isFromAdmin
                    ? LinearGradient(colors: [_mediumPurple, _darkPurple])
                    : null,
                color: isFromAdmin ? null : _white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isFromAdmin ? const Radius.circular(4) : null,
                  bottomLeft: isFromAdmin ? null : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isFromAdmin ? null : Border.all(color: _mediumPurple.withOpacity(0.2)),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isFromAdmin ? _white : _darkPurple,
                  fontSize: 16,
                ),
              ),
            ),
            if (timeStr.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: isFromAdmin ? 0 : 12,
                  right: isFromAdmin ? 12 : 0,
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

  Widget _buildMessageInput() {
    return Container(
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
                hintText: 'Type your response...',
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
              textInputAction: TextInputAction.send,
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
    );
  }

  void _showUserInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('User Information', style: TextStyle(color: _darkPurple)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name:', widget.chatData['userName'] as String? ??
                (widget.chatData['userEmail'] as String?)?.split('@')[0] ?? 'Unknown'),
            _buildInfoRow('Email:', widget.chatData['userEmail'] as String? ?? 'Unknown'),
            _buildInfoRow('Status:', widget.chatData['isActive'] as bool? ?? true ? 'Active' : 'Resolved'),
            _buildInfoRow('Chat ID:', widget.chatId),
            if (widget.chatData['createdAt'] != null)
              _buildInfoRow(
                'Created:',
                _formatDate((widget.chatData['createdAt'] as Timestamp).toDate()),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: _mediumPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _greyText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: _darkPurple),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}