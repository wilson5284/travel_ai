// lib/screens/chatbot_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import the markdown package
import '../widgets/typing_indicator.dart'; // Import your new typing indicator widget

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String _preferredLanguage = 'English';
  String? _userId;
  String? _currentChatSessionId;

  static const String deepSeekKey = 'sk-7f50d215dd784f7a82a12212c8802525';

  static const Set<String> _travelKeywords = {
    'trip', 'travel', 'plan', 'destination', 'flight', 'hotel', 'visa',
    'explore', 'visit', 'itinerary', 'vacation', 'journey', 'tour', 'adventure',
    'accommodation', 'transport', 'guide', 'route', 'sightseeing', 'package',
    'book', 'reservation', 'ticket', 'departure', 'arrival', 'airport',
    'station', 'museum', 'beach', 'mountain', 'city', 'country', 'passport',
    'currency', 'local', 'culture', 'food', 'restaurant', 'shopping', 'activity',
    'train', 'bus', 'car', 'cruise', 'ferry', 'map', 'direction', 'luggage',
    'packing', 'safety', 'emergency', 'customs', 'border', 'exchange rate',
    'time difference', 'weather', 'climate', 'festival', 'event', 'attraction',
    'landmark', 'historical site', 'national park', 'wildlife', 'safari',
    'trekking', 'hiking', 'camping', 'backpacking', 'resort', 'motel', 'hostel',
    'bungalow', 'villa', 'condo', 'apartment', 'air bnb', 'guesthouse',
    'bed and breakfast', 'inn', 'residency', 'suite', 'room', 'check-in', 'check-out'
  };

  @override
  void initState() {
    super.initState();
    _initializeChatbot();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChatbot() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      await _loadUserPreferredLanguage();
      await _loadChatSession(null);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to use the chatbot.')),
        );
      }
    }
  }

  Future<void> _loadUserPreferredLanguage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final lang = doc.data()?['preferredLanguage'] ?? 'English';
      setState(() {
        _preferredLanguage = lang;
      });
    }
  }

  Future<void> _loadChatSession(String? sessionIdToLoad) async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;

      if (sessionIdToLoad != null) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('chat_sessions')
            .doc(sessionIdToLoad)
            .get();
        _currentChatSessionId = sessionIdToLoad;
      } else {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('chat_sessions')
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          doc = querySnapshot.docs.first;
          _currentChatSessionId = doc.id;
        }
      }

      if (doc != null && doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List<dynamic> messagesData = data['messages'] ?? [];
        setState(() {
          _messages.clear(); // Clear messages before adding new ones
          _messages.addAll(messagesData.map((msg) {
            return {
              'role': msg['role'] as String,
              'content': msg['content'] as String,
              'timestamp': msg['timestamp'] as Timestamp,
            };
          }).toList());
        });
        _scrollToBottom();
      } else {
        await _startNewChat(sendGreeting: true);
      }
    } catch (e) {
      print('Error loading chat session: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading chat history. Starting a new chat.')),
        );
      }
      await _startNewChat(sendGreeting: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startNewChat({bool sendGreeting = true}) async {
    if (_userId == null) return;

    setState(() {
      _messages.clear();
      _isLoading = true;
    });

    _currentChatSessionId = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('chat_sessions')
        .doc()
        .id;

    if (sendGreeting) {
      await _sendInitialGreeting();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _saveCurrentMessage(Map<String, dynamic> message) async {
    if (_userId == null || _currentChatSessionId == null) return;

    final chatSessionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('chat_sessions')
        .doc(_currentChatSessionId);

    _messages.add(message);

    try {
      await chatSessionRef.set(
        {
          'messages': _messages,
          'lastUpdated': FieldValue.serverTimestamp(),
          'startTime': _messages.length == 1
              ? FieldValue.serverTimestamp()
              : (await chatSessionRef.get()).data()?['startTime'] ?? FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  Future<void> _sendInitialGreeting() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $deepSeekKey',
    };
    final body = json.encode({
      "model": "deepseek-chat",
      "messages": [
        {
          "role": "system",
          "content": "You are a friendly and helpful travel assistant chatbot. Greet the user and ask how you can assist them with their travel plans. Keep your greeting concise and friendly. Reply in clean sentences with no markdown."
        }
      ],
      "temperature": 0.7
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data['choices'] != null &&
          data['choices'].isNotEmpty &&
          data['choices'][0]['message'] != null) {
        String greeting = data['choices'][0]['message']['content'];
        // Keep _formatResponse commented out or remove it here if it interferes with DeepSeek's desired formatting
        // greeting = _formatResponse(greeting);

        if (_preferredLanguage != 'English') {
          greeting = await _translateText(greeting, _preferredLanguage);
        }

        final assistantMessage = {
          'role': 'assistant',
          'content': greeting,
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(assistantMessage);

      } else {
        final fallbackMessage = {
          'role': 'assistant',
          'content': 'Hello! How can I assist you with your travel plans today?',
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(fallbackMessage);
      }
    } catch (e) {
      print('Error sending initial greeting: $e');
      final fallbackMessage = {
        'role': 'assistant',
        'content': 'Hello! How can I assist you with your travel plans today?',
        'timestamp': Timestamp.now(),
      };
      await _saveCurrentMessage(fallbackMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;
    if (_userId == null || _currentChatSessionId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat is not initialized. Please try again or log in.')),
        );
      }
      return;
    }

    final userMessage = {
      'role': 'user',
      'content': userInput,
      'timestamp': Timestamp.now(),
    };
    await _saveCurrentMessage(userMessage);
    _controller.clear();

    setState(() {
      _isLoading = true;
    });
    _scrollToBottom();

    // --- START OF MODIFIED LOGIC FOR KEYWORD CHECK ---
    bool isTravelQuestion = false;
    String processedInputForKeywordCheck = userInput;

    // Only translate for keyword check if not already in English
    if (_preferredLanguage != 'English') {
      processedInputForKeywordCheck = await _translateText(userInput, 'English');
    }

    final lowerCaseProcessedInput = processedInputForKeywordCheck.toLowerCase();
    for (final keyword in _travelKeywords) {
      if (lowerCaseProcessedInput.contains(keyword)) {
        isTravelQuestion = true;
        break;
      }
    }

    if (!isTravelQuestion) {
      final assistantMessage = {
        'role': 'assistant',
        'content': '❗️This chatbot is designed to answer travel-related questions only. Please ask something about travel.',
        'timestamp': Timestamp.now(),
      };
      await _saveCurrentMessage(assistantMessage);
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }
    // --- END OF MODIFIED LOGIC FOR KEYWORD CHECK ---

    final url = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $deepSeekKey',
    };

    List<Map<String, String>> conversationHistoryForAI = [];
    conversationHistoryForAI.add({
      "role": "system",
      "content": "You are a helpful travel assistant. Always answer questions about travel, tourism, places, itineraries, safety, visas, transportation, languages, and culture. Reply in clear, friendly sentences with proper Markdown formatting for lists, bold text, and paragraphs. Do not include introductory phrases like 'Here's your itinerary:' but start directly with the content."
    });
    for (var msg in _messages) {
      conversationHistoryForAI.add({
        'role': msg['role'] as String,
        'content': msg['content'] as String,
      });
    }

    final body = json.encode({
      "model": "deepseek-chat",
      "messages": conversationHistoryForAI,
      "temperature": 0.7
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data['choices'] != null &&
          data['choices'].isNotEmpty &&
          data['choices'][0]['message'] != null) {
        String reply = data['choices'][0]['message']['content'];

        // --- START OF MODIFIED CODE FOR CHARACTER REPLACEMENT ---
        // This addresses the "weird wording" like 'â' and '' appearing.
        // It's common for smart quotes or other special characters to be misinterpreted
        // if encoding is not perfectly consistent.
        reply = reply.replaceAll('â', "'"); // Existing fix for 'â'
        reply = reply.replaceAll('â€œ', '“').replaceAll('â€ ', '”'); // For smart double quotes
        reply = reply.replaceAll('â€™', '’'); // For smart single quote/apostrophe
        reply = reply.replaceAll('â€”', '—'); // For em dash
        reply = reply.replaceAll('â€“', '–'); // For en dash
        reply = reply.replaceAll('â€¦', '…'); // For ellipsis

        reply = reply.replaceAll('Ã©', 'é'); // for accented e
        reply = reply.replaceAll('Ã¨', 'è'); // for accented e
        reply = reply.replaceAll('Ã¢', 'â'); // for accented a
        reply = reply.replaceAll('Ã®', 'î'); // for accented i

        reply = reply.replaceAll('â\x80\x99', "'"); // Specific replacement for U+2019 Right Single Quotation Mark if misencoded
        reply = reply.replaceAll('â\x80\x9C', '“'); // Specific replacement for U+201C Left Double Quotation Mark
        reply = reply.replaceAll('â\x80\x9D', '”'); // Specific replacement for U+201D Right Double Quotation Mark
        reply = reply.replaceAll('â\x80\x93', '–'); // Specific replacement for U+2013 En Dash
        reply = reply.replaceAll('â\x80\x94', '—'); // Specific replacement for U+2014 Em Dash
        reply = reply.replaceAll('â\x80\xA6', '…'); // Specific replacement for U+2026 Horizontal Ellipsis

        // Replaces the Unicode replacement character itself if it appears.
        // This specifically targets the '' character.
        reply = reply.replaceAll(RegExp(r'[\uFFFD]'), '');
        // --- END OF MODIFIED CODE FOR CHARACTER REPLACEMENT ---


        if (_preferredLanguage != 'English') {
          reply = await _translateText(reply, _preferredLanguage);
        }

        final assistantMessage = {
          'role': 'assistant',
          'content': reply, // Store the processed Markdown content
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(assistantMessage);

      } else {
        final errorMessage = {
          'role': 'assistant',
          'content': 'AI did not return a response. Please try again.',
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(errorMessage);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI did not return a response.')),
          );
        }
      }
    } catch (e) {
      final errorMessage = {
        'role': 'assistant',
        'content': 'Error processing your request. Please try again later.',
        'timestamp': Timestamp.now(),
      };
      await _saveCurrentMessage(errorMessage);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _translateText(String text, String language) async {
    if (language.toLowerCase() == 'english') return text;

    final url = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $deepSeekKey',
    };
    final body = json.encode({
      "model": "deepseek-chat",
      "messages": [
        {"role": "system", "content": "Translate the following into $language. Just provide the translated text without any additional commentary."},
        {"role": "user", "content": text},
      ],
      "temperature": 0.3,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data['choices'] != null &&
          data['choices'].isNotEmpty &&
          data['choices'][0]['message'] != null) {
        return data['choices'][0]['message']['content']?.trim() ?? text;
      } else {
        return text;
      }
    } catch (e) {
      print('Translation error: $e');
      return text;
    }
  }


  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final timestamp = (msg['timestamp'] as Timestamp?)?.toDate();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Use MarkdownBody for assistant messages to render Markdown
            isUser
                ? Text(
              msg['content'] ?? '',
              style: const TextStyle(fontSize: 15, height: 1.4),
            )
                : MarkdownBody(
              data: msg['content'] ?? '',
              styleSheet: MarkdownStyleSheet(
                // You can customize the styles here
                p: const TextStyle(fontSize: 15, height: 1.4),
                listBullet: const TextStyle(fontSize: 15, height: 1.4),
                // Add more styles for headings, bold, etc., if needed
              ),
            ),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDateCategory(DateTime messageDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final date = DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (date.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else if (date.isAfter(sevenDaysAgo)) {
      return 'Previous 7 Days';
    } else {
      return 'Older Chats';
    }
  }

  String _formatMonthYear(String monthYearKey) {
    final parts = monthYearKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthName = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][month];
    return '$monthName $year';
  }

  void _addSessionListTile(List<Widget> drawerItems, QueryDocumentSnapshot sessionDoc, Map<String, dynamic> sessionData, Timestamp? lastUpdated, List<dynamic> messages) {
    String chatSummary = 'Empty Chat';
    if (messages.isNotEmpty) {
      final firstUserMessage = messages.firstWhere(
            (msg) => msg['role'] == 'user' && msg['content'] != null && (msg['content'] as String).trim().isNotEmpty,
        orElse: () => null,
      );

      if (firstUserMessage != null) {
        chatSummary = firstUserMessage['content'] as String;
        if (chatSummary.length > 50) {
          chatSummary = '${chatSummary.substring(0, 47)}...';
        }
      } else {
        final firstActualMessage = messages.firstWhere(
              (msg) => msg['content'] != null && (msg['content'] as String).trim().isNotEmpty,
          orElse: () => {'content': 'New chat session'},
        )['content'] as String;
        chatSummary = firstActualMessage;
        if (chatSummary.length > 50) {
          chatSummary = '${chatSummary.substring(0, 47)}...';
        }
      }
    } else if (sessionData['startTime'] != null) {
      chatSummary = 'New chat started';
    }

    String formattedTime;
    final now = DateTime.now();
    if (lastUpdated != null) {
      final DateTime lastUpdatedDate = lastUpdated.toDate().toLocal();
      final String category = _getDateCategory(lastUpdatedDate, now);

      if (category == 'Today' || category == 'Yesterday') {
        formattedTime = 'Last activity: ${lastUpdatedDate.hour.toString().padLeft(2, '0')}:${lastUpdatedDate.minute.toString().padLeft(2, '0')}';
      } else {
        formattedTime = 'Last activity: ${lastUpdatedDate.month}/${lastUpdatedDate.day}/${lastUpdatedDate.year}';
      }
    } else {
      formattedTime = 'No activity';
    }

    if (messages.isEmpty && sessionData['startTime'] is Timestamp) {
      final startTime = (sessionData['startTime'] as Timestamp).toDate().toLocal();
      formattedTime = 'Started: ${startTime.month}/${startTime.day}/${startTime.year} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      chatSummary = 'New Chat on ${startTime.month}/${startTime.day}';
    }

    drawerItems.add(
      ListTile(
        title: Text(chatSummary, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(formattedTime),
        selected: _currentChatSessionId == sessionDoc.id,
        onTap: () {
          Navigator.pop(context);
          if (_currentChatSessionId != sessionDoc.id) {
            _loadChatSession(sessionDoc.id);
          }
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel AI Chat"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open chat history',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
            onPressed: _isLoading ? null : () => _startNewChat(sendGreeting: true),
            tooltip: 'Start a New Chat',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[700]),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Your Chat History',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            Expanded(
              child: _userId == null
                  ? const Center(child: Text('Please log in to see chat history.'))
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_userId)
                    .collection('chat_sessions')
                    .orderBy('lastUpdated', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No previous chats.'));
                  }

                  final chatSessions = snapshot.data!.docs;
                  final now = DateTime.now();

                  final Map<String, List<QueryDocumentSnapshot>> groupedSessions = {
                    'Today': [],
                    'Yesterday': [],
                    'Previous 7 Days': [],
                    'Older Chats': [],
                  };

                  for (var sessionDoc in chatSessions) {
                    final sessionData = sessionDoc.data() as Map<String, dynamic>;
                    final Timestamp? lastUpdatedTimestamp = sessionData['lastUpdated'] as Timestamp?;
                    if (lastUpdatedTimestamp != null) {
                      final DateTime lastUpdatedDate = lastUpdatedTimestamp.toDate();
                      final category = _getDateCategory(lastUpdatedDate, now);
                      groupedSessions[category]?.add(sessionDoc);
                    }
                  }

                  final Map<String, List<QueryDocumentSnapshot>> olderChatsByMonth = {};
                  if (groupedSessions['Older Chats'] != null) {
                    for (var sessionDoc in groupedSessions['Older Chats']!) {
                      final sessionData = sessionDoc.data() as Map<String, dynamic>;
                      final Timestamp? lastUpdatedTimestamp = sessionData['lastUpdated'] as Timestamp?;
                      if (lastUpdatedTimestamp != null) {
                        final DateTime date = lastUpdatedTimestamp.toDate().toLocal();
                        final String monthYearKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                        olderChatsByMonth.putIfAbsent(monthYearKey, () => []).add(sessionDoc);
                      }
                    }
                  }

                  List<Widget> drawerItems = [];

                  groupedSessions.forEach((category, sessions) {
                    if (sessions.isNotEmpty) {
                      drawerItems.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      );

                      if (category == 'Older Chats') {
                        final sortedMonthYearKeys = olderChatsByMonth.keys.toList()
                          ..sort((a, b) => b.compareTo(a)); // Sort by most recent month/year first
                        for (final monthYearKey in sortedMonthYearKeys) {
                          drawerItems.add(
                            Padding(
                              padding: const EdgeInsets.only(left: 32.0, top: 4.0, bottom: 4.0),
                              child: Text(
                                _formatMonthYear(monthYearKey),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                          for (var sessionDoc in olderChatsByMonth[monthYearKey]!) {
                            final sessionData = sessionDoc.data() as Map<String, dynamic>;
                            final List<dynamic> messages = sessionData['messages'] ?? [];
                            final Timestamp? lastUpdated = sessionData['lastUpdated'] as Timestamp?;
                            _addSessionListTile(drawerItems, sessionDoc, sessionData, lastUpdated, messages);
                          }
                        }
                      } else {
                        for (var sessionDoc in sessions) {
                          final sessionData = sessionDoc.data() as Map<String, dynamic>;
                          final List<dynamic> messages = sessionData['messages'] ?? [];
                          final Timestamp? lastUpdated = sessionData['lastUpdated'] as Timestamp?;
                          _addSessionListTile(drawerItems, sessionDoc, sessionData, lastUpdated, messages);
                        }
                      }
                      drawerItems.add(const Divider(height: 1));
                    }
                  });

                  return ListView(children: drawerItems);
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: TypingIndicator(), // Use your new TypingIndicator widget
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about flights, places, visas...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
<<<<<<< HEAD
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
=======
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
    );
  }
}