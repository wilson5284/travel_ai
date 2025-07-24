// lib/screens/chatbot_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard functionality
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/typing_indicator.dart';

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

  // New variables for in-chat search functionality (like the screenshot)
  bool _isInChatSearching = false; // To control visibility of the in-chat search bar
  final TextEditingController _inChatSearchController = TextEditingController();
  String _inChatSearchQuery = '';
  List<int> _matchingMessageIndices = []; // Stores indices of messages with search query
  int _currentMatchIndex = -1; // Index of the currently highlighted match

  // New variables for drawer search functionality
  final TextEditingController _drawerSearchController = TextEditingController();
  String _drawerSearchQuery = '';


  static const String geminiKey = 'AIzaSyATwBN9CJBt5fl9BNJ8k3WahI2HF8CY94g';

  static const String _geminiModel = 'gemini-1.5-flash';

  static const Set<String> _travelKeywords = {
    'trip', 'travel', 'plan', 'destination', 'flight', 'hotel', 'visa',
    'explore', 'visit', 'itinerary', 'vacation', 'journey', 'tour', 'adventure',
    'accommodation', 'transport', 'guide', 'route', 'sightseeing', 'package',
    'book', 'reservation', 'ticket', 'departure', 'arrival', 'airport',
    'station', 'museum', 'beach', 'mountain', 'city', 'country', 'passport',
    'currency', 'local', 'culture', 'food', 'restaurant', 'shopping', 'activity',
    'train', 'bus', 'car', 'cruise', 'ferry', 'map', 'direction', 'luggage',
    'packing', 'safety', 'emergency', 'customs', 'border', 'exchange rate',
    'time difference',
    'festival', 'event', 'attraction',
    'landmark', 'historical site', 'national park', 'wildlife', 'safari',
    'trekking', 'hiking', 'camping', 'backpacking', 'resort', 'motel', 'hostel',
    'bungalow', 'villa', 'condo', 'apartment', 'air bnb', 'guesthouse',
    'bed and breakfast', 'inn', 'residency', 'suite', 'room', 'check-in', 'check-out'
  };

  // Define color scheme consistent with InsuranceSuggestionScreen
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _white = Colors.white;
  final Color _greyText = Colors.grey.shade600;


  @override
  void initState() {
    super.initState();
    _initializeChatbot();
    _inChatSearchController.addListener(_onInChatSearchChanged);
    _drawerSearchController.addListener(_onDrawerSearchChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inChatSearchController.dispose();
    _drawerSearchController.dispose();
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
      _isInChatSearching = false; // Reset in-chat search state
      _inChatSearchController.clear();
      _inChatSearchQuery = '';
      _matchingMessageIndices.clear();
      _currentMatchIndex = -1;
      _drawerSearchController.clear(); // Clear drawer search
      _drawerSearchQuery = ''; // Clear drawer search query
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
          // No need to filter messages here, _onInChatSearchChanged handles it
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
      _isInChatSearching = false; // Reset in-chat search state
      _inChatSearchController.clear();
      _inChatSearchQuery = '';
      _matchingMessageIndices.clear();
      _currentMatchIndex = -1;
      _drawerSearchController.clear(); // Clear drawer search
      _drawerSearchQuery = ''; // Clear drawer search query
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
    // After adding a new message, re-run in-chat search if active
    if (_isInChatSearching && _inChatSearchQuery.isNotEmpty) {
      _onInChatSearchChanged();
    }

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

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$geminiKey');
    final headers = {
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      "contents": [
        {
          "parts": [
            {"text": "You are a friendly and helpful travel assistant chatbot. Greet the user and ask how you can assist them with their travel plans. Keep your greeting concise and friendly. Reply in clean sentences with no markdown."}
          ]
        }
      ],
      "safetySettings": [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data['candidates'] != null &&
          data['candidates'].isNotEmpty &&
          data['candidates'][0]['content'] != null &&
          data['candidates'][0]['content']['parts'] != null &&
          data['candidates'][0]['content']['parts'].isNotEmpty) {
        String greeting = data['candidates'][0]['content']['parts'][0]['text'];

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

    bool isTravelQuestion = false;
    String processedInputForKeywordCheck = userInput;

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

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$geminiKey');
    final headers = {
      'Content-Type': 'application/json',
    };

    List<Map<String, dynamic>> conversationHistoryForAI = [];
    conversationHistoryForAI.add({
      "role": "user",
      "parts": [
        {"text": "You are a helpful travel assistant. Always answer questions about travel, tourism, places, itineraries, safety, visas, transportation, languages, and culture. Reply in clear, friendly sentences with proper Markdown formatting for lists, bold text, and paragraphs. Do not include introductory phrases like 'Here's your itinerary:' but start directly with the content."}
      ]
    });

    for (var msg in _messages) {
      conversationHistoryForAI.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['content'] as String},
        ],
      });
    }

    final body = json.encode({
      "contents": conversationHistoryForAI,
      "safetySettings": [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data['candidates'] != null &&
          data['candidates'].isNotEmpty &&
          data['candidates'][0]['content'] != null &&
          data['candidates'][0]['content']['parts'] != null &&
          data['candidates'][0]['content']['parts'].isNotEmpty) {
        String reply = data['candidates'][0]['content']['parts'][0]['text'];

        reply = reply.replaceAll('â', "'");
        reply = reply.replaceAll('â€œ', '“').replaceAll('â€ ', '”');
        reply = reply.replaceAll('â€™', '’');
        reply = reply.replaceAll('â€”', '—');
        reply = reply.replaceAll('â€“', '–');
        reply = reply.replaceAll('â€¦', '…');

        reply = reply.replaceAll('Ã©', 'é');
        reply = reply.replaceAll('Ã¨', 'è');
        reply = reply.replaceAll('Ã¢', 'â');
        reply = reply.replaceAll('Ã®', 'î');

        reply = reply.replaceAll(RegExp(r'[\uFFFD]'), '');


        if (_preferredLanguage != 'English') {
          reply = await _translateText(reply, _preferredLanguage);
        }

        final assistantMessage = {
          'role': 'assistant',
          'content': reply,
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(assistantMessage);

      } else {
        String errorMessage = 'AI did not return a valid response. Please try again.';
        if (data['promptFeedback'] != null && data['promptFeedback']['safetyRatings'] != null) {
          bool blocked = false;
          for (var rating in data['promptFeedback']['safetyRatings']) {
            if (rating['blocked'] == true) {
              blocked = true;
              break;
            }
          }
          if (blocked) {
            errorMessage = 'Your input was flagged by safety filters. Please rephrase your question.';
          }
        }
        final errorMessageData = {
          'role': 'assistant',
          'content': errorMessage,
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(errorMessageData);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
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

  // --- In-Chat Search Functions ---

  void _toggleInChatSearch() {
    setState(() {
      _isInChatSearching = !_isInChatSearching;
      if (!_isInChatSearching) {
        _inChatSearchController.clear();
        _inChatSearchQuery = '';
        _matchingMessageIndices.clear();
        _currentMatchIndex = -1;
      } else {
        // If entering search, trigger a search on current messages if query exists
        if (_inChatSearchQuery.isNotEmpty) {
          _onInChatSearchChanged();
        }
      }
    });
  }

  void _onInChatSearchChanged() {
    setState(() {
      _inChatSearchQuery = _inChatSearchController.text;
      _matchingMessageIndices.clear();
      _currentMatchIndex = -1; // Reset current match index

      if (_inChatSearchQuery.isNotEmpty) {
        final lowerCaseQuery = _inChatSearchQuery.toLowerCase();
        for (int i = 0; i < _messages.length; i++) {
          final content = _messages[i]['content']?.toLowerCase() ?? '';
          if (content.contains(lowerCaseQuery)) {
            _matchingMessageIndices.add(i);
          }
        }
        if (_matchingMessageIndices.isNotEmpty) {
          _currentMatchIndex = 0; // Set to the first match
          _scrollToMatch(_currentMatchIndex);
        }
      }
    });
  }

  void _goToNextMatch() {
    if (_matchingMessageIndices.isNotEmpty) {
      setState(() {
        _currentMatchIndex = (_currentMatchIndex + 1) % _matchingMessageIndices.length;
        _scrollToMatch(_currentMatchIndex);
      });
    }
  }

  void _goToPreviousMatch() {
    if (_matchingMessageIndices.isNotEmpty) {
      setState(() {
        _currentMatchIndex = (_currentMatchIndex - 1 + _matchingMessageIndices.length) % _matchingMessageIndices.length;
        _scrollToMatch(_currentMatchIndex);
      });
    }
  }

  void _scrollToMatch(int matchIndexInList) {
    if (matchIndexInList >= 0 && matchIndexInList < _matchingMessageIndices.length) {
      final int messageIndex = _matchingMessageIndices[matchIndexInList];
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          // Calculate the scroll offset. This is a simplified approach.
          // For more accurate scrolling, you might need to use GlobalKey and RenderBox
          // to get the exact position of the widget.
          final double itemHeightEstimate = 70.0; // Estimate average message height
          final double offset = messageIndex * itemHeightEstimate;

          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }


  // --- Drawer Search Functions ---

  void _onDrawerSearchChanged() {
    setState(() {
      _drawerSearchQuery = _drawerSearchController.text;
    });
  }

  Future<String> _translateText(String text, String language) async {
    if (language.toLowerCase() == 'english') return text;

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$geminiKey');
    final headers = {
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      "contents": [
        {
          "parts": [
            {"text": "Translate the following into $language. Just provide the translated text without any additional commentary."},
          ]
        },
        {
          "role": "user",
          "parts": [
            {"text": text},
          ]
        }
      ],
      "safetySettings": [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data['candidates'] != null &&
          data['candidates'].isNotEmpty &&
          data['candidates'][0]['content'] != null &&
          data['candidates'][0]['content']['parts'] != null &&
          data['candidates'][0]['content']['parts'].isNotEmpty) {
        return data['candidates'][0]['content']['parts'][0]['text']?.trim() ?? text;
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, int messageIndex) {
    final isUser = msg['role'] == 'user';
    final timestamp = (msg['timestamp'] as Timestamp?)?.toDate();
    final content = msg['content'] ?? '';

    // Determine if this message should be highlighted as a search result
    final bool isSearchMatch = _isInChatSearching &&
        _inChatSearchQuery.isNotEmpty &&
        content.toLowerCase().contains(_inChatSearchQuery.toLowerCase());

    final bool isCurrentHighlight = isSearchMatch &&
        _currentMatchIndex != -1 &&
        _matchingMessageIndices.isNotEmpty &&
        _matchingMessageIndices[_currentMatchIndex] == messageIndex;

    // Updated colors for chat bubbles
    Color? backgroundColor = isUser ? _lightPurple : _white; // User messages light purple, assistant messages white
    if (isCurrentHighlight) {
      backgroundColor = Colors.yellow[200]; // Highlight current match
    } else if (isSearchMatch) {
      backgroundColor = _mediumPurple.withOpacity(0.3); // Highlight other matches with a purple tint
    }

    Widget messageContentWidget;
    if (isUser) {
      messageContentWidget = Text(
        content,
        style: TextStyle(fontSize: 15, height: 1.4, color: _darkPurple), // User text dark purple
      );
    } else {
      messageContentWidget = GestureDetector(
        onLongPress: () => _copyToClipboard(content),
        child: MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 15, height: 1.4, color: _greyText), // Assistant text grey
            listBullet: TextStyle(fontSize: 15, height: 1.4, color: _greyText),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            messageContentWidget, // Use the prepared widget
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
        title: Text(
          "Travel AI Chat",
          style: TextStyle(
            color: _darkPurple, // Consistent app bar title color
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _white, // Consistent app bar background
        elevation: 0, // No shadow for app bar
        iconTheme: IconThemeData(color: _darkPurple), // Back button color
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: _darkPurple), // Toggle in-chat search
            onPressed: _toggleInChatSearch,
            tooltip: 'Search Chat',
          ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: _darkPurple),
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
              decoration: BoxDecoration(color: _darkPurple), // Dark purple for drawer header
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Your Chat History',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            // Drawer search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _drawerSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search chat history...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _onDrawerSearchChanged(),
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

                  List<QueryDocumentSnapshot> chatSessions = snapshot.data!.docs;

                  // Filter chat sessions based on _drawerSearchQuery
                  if (_drawerSearchQuery.isNotEmpty) {
                    final lowerCaseDrawerQuery = _drawerSearchQuery.toLowerCase();
                    chatSessions = chatSessions.where((sessionDoc) {
                      final sessionData = sessionDoc.data() as Map<String, dynamic>;
                      final List<dynamic> messages = sessionData['messages'] ?? [];
                      String chatSummary = 'Empty Chat'; // Default summary

                      if (messages.isNotEmpty) {
                        // Try to find the first non-empty user message for summary
                        final firstUserMessage = messages.firstWhere(
                              (msg) => msg['role'] == 'user' && msg['content'] != null && (msg['content'] as String).trim().isNotEmpty,
                          orElse: () => null,
                        );

                        if (firstUserMessage != null) {
                          chatSummary = firstUserMessage['content'] as String;
                        } else {
                          // Fallback to first non-empty message overall
                          final firstActualMessage = messages.firstWhere(
                                (msg) => msg['content'] != null && (msg['content'] as String).trim().isNotEmpty,
                            orElse: () => {'content': 'New chat session'},
                          )['content'] as String;
                          chatSummary = firstActualMessage;
                        }
                      } else if (sessionData['startTime'] is Timestamp) {
                        final startTime = (sessionData['startTime'] as Timestamp).toDate().toLocal();
                        chatSummary = 'New chat started on ${startTime.month}/${startTime.day}';
                      }

                      return chatSummary.toLowerCase().contains(lowerCaseDrawerQuery);
                    }).toList();
                  }

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
                          ..sort((a, b) => b.compareTo(a));
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
      body: Container( // Wrap body with Container for gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3E5F5), // Light violet
              Color(0xFFFFF5E6), // Light beige
            ],
          ),
        ),
        child: Column(
          children: [
            if (_isInChatSearching)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inChatSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search in chat...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        ),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (_) => _onInChatSearchChanged(),
                      ),
                    ),
                    if (_inChatSearchQuery.isNotEmpty && _matchingMessageIndices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '${_currentMatchIndex + 1} of ${_matchingMessageIndices.length}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: _matchingMessageIndices.isNotEmpty ? _goToPreviousMatch : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: _matchingMessageIndices.isNotEmpty ? _goToNextMatch : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _toggleInChatSearch, // Closes the search bar
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessage(_messages[i], i), // Pass message index for highlighting
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: TypingIndicator(),
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
                      decoration: InputDecoration( // Apply theme to input field
                        hintText: 'Ask about flights, places, visas...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _mediumPurple.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _mediumPurple.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _darkPurple,
                            width: 2.0,
                          ),
                        ),
                        fillColor: _lightBeige.withOpacity(0.6),
                        filled: true,
                        hintStyle: TextStyle(
                          color: _greyText.withOpacity(0.6),
                        ),
                      ),
                      style: TextStyle(
                        color: _darkPurple,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isLoading ? null : _sendMessage,
                    color: _darkPurple, // Consistent button color
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}