// lib/screens/chatbot/chatbot_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../widgets/typing_indicator.dart';

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
  String _preferredLanguage = 'en'; // This will still be loaded but primarily for UI preferences or other features, not for AI response language.
  String? _userId;
  String? _currentChatSessionId;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isShareMenuOpen = false;

  // New variables for in-chat search functionality (like the screenshot)
  bool _isInChatSearching = false; // To control visibility of the in-chat search bar
  final TextEditingController _inChatSearchController = TextEditingController();
  String _inChatSearchQuery = '';
  final List<int> _matchingMessageIndices = []; // Stores indices of messages with search query
  int _currentMatchIndex = -1; // Index of the currently highlighted match

  // New variables for drawer search functionality
  final TextEditingController _drawerSearchController = TextEditingController();
  String _drawerSearchQuery = '';

  static const String geminiKey = 'AIzaSyATwBN9CJBt5fl9BNJ8k3WahI2HF8CY94g';
  static const String _cloudTranslationApiKey = 'AIzaSyAA2CBf5lgQJ8Lrfbe1eui35HHw-4QuXfM';
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
    'bed and breakfast', 'inn', 'residency', 'suite', 'room', 'check-in', 'check-out','规划',
    '旅游', '旅行', '目的地', '航班', '酒店', '签证', '探索', '访问', '行程', '假期',
    '旅程', '观光', '冒险', '住宿', '交通', '导游', '路线', '景点', '套餐', '预订',
    '订票', '出发', '到达', '机场', '车站', '博物馆', '海滩', '山', '城市', '国家',
    '护照', '货币', '当地', '文化', '食物', '餐厅', '购物', '活动', '火车', '巴士',
    '汽车', '邮轮', '渡轮', '地图', '方向', '行李', '打包', '安全', '紧急情况', '海关',
    '边境', '汇率', '时差', '节日', '地标', '历史遗迹', '国家公园',
    '野生动物', '野生动物园', '徒步', '露营', '背包旅行', '度假村', '汽车旅馆', '旅社',
    '平房', '别墅', '公寓', '民宿', '旅馆', '住宿加早餐', '套房', '房间',
    '入住', '退房','一日游',
    // Basic travel terms in Bahasa Melayu
    'perjalanan', 'pelancongan', 'melancong', 'bercuti', 'percutian',
    'destinasi', 'tujuan', 'penerbangan', 'pasport',
    'tiket', 'tempahan', 'aktiviti', 'lawatan', 'jelajah', 'pengalaman',
    'penginapan', 'chalet', 'homestay', 'backpacker',
    'pengangkutan', 'kereta', 'bas', 'kapal terbang',
    'lapangan terbang', 'stesen', 'pelabuhan', 'terminal',
    'bagasi', 'beg', 'pakaian', 'keperluan', 'bekalan',
    'peta', 'arah', 'panduan', 'pemandu pelancong',
    'tempat menarik', 'tarikan', 'pantai', 'gunung', 'hutan',
    'bandar', 'kampung', 'negara', 'negeri', 'wilayah',
    'budaya', 'tradisi', 'perayaan', 'makanan',
    'restoran', 'kedai makan', 'warung', 'gerai', 'pasar',
    'membeli belah', 'cenderahati', 'souvenir',
    'wang', 'mata wang', 'pertukaran wang', 'kos', 'belanja',
    'bajet', 'murah', 'mahal', 'promosi', 'diskaun',
    'keselamatan', 'selamat', 'kecemasan', 'hospital', 'klinik',
    'polis', 'kastam', 'imigresen', 'sempadan', 'kawalan',
    'masuk', 'keluar', 'daftar masuk',
    'muzium', 'galeri', 'istana', 'masjid', 'kuil', 'gereja',
    'taman negara', 'cagar alam', 'hidupan liar',
    'mendaki', 'berkhemah', 'memancing',
    'menyelam', 'snorkeling', 'berenang', 'bermain ski air',
    'spa', 'urut', 'rekreasi', 'hiburan', 'sukan air',
    'kapal pesiar', 'bot', 'feri', 'keretapi', 'mrt', 'lrt',
    'teksi', 'grab', 'bas ekspres', 'bas bandar', 'motor',
    'sewa kereta', 'pemanduan', 'lesen memandu', 'insurans perjalanan',
    // Japanese travel keywords
    '観光', '休暇', 'フライト', 'ホテル', 'ビザ',
    'パスポート', 'チケット', '予約', 'アクティビティ', '宿泊', 'ガイド', 'ビーチ', '都市',
    '国', '食べ物', 'レストラン', 'ショッピング', '空港', '駅', '博物館'
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
      // Consider using a logging framework like `logger` or `flutter_flogger`
      // For now, replacing print with debugPrint for development visibility without affecting release builds.
      debugPrint('Error loading chat session: $e');
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
      debugPrint('Error saving chat history: $e');
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

        // Initial greeting should still be translated based on _preferredLanguage
        // as this is a general greeting, not a dynamic response to user input yet.
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
      debugPrint('Error sending initial greeting: $e');
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

    // 1. Detect the language of the current user input using Cloud Translation API
    final String detectedInputLanguageCode = await _detectLanguage(userInput);

    bool isTravelQuestion = false;
    final lowerCaseUserInput = userInput.toLowerCase();

    // Check for keywords in the *original* user input (preferred language and Chinese keywords are already included)
    for (final keyword in _travelKeywords) {
      if (lowerCaseUserInput.contains(keyword.toLowerCase())) {
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

    // From here, we know it's a travel question.
    // Now, prepare the conversation history for the Gemini API.

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$geminiKey');
    final headers = {
      'Content-Type': 'application/json',
    };

    List<Map<String, dynamic>> conversationHistoryForAI = [];

    // Construct a dynamic system instruction for Gemini based on detected language
    String systemInstruction = "You are a helpful travel assistant. Always answer questions about travel, tourism, places, itineraries, safety, visas, transportation, languages, and culture. Reply in clear, friendly sentences with proper Markdown formatting for lists, bold text, and paragraphs. Do not include introductory phrases like 'Here's your itinerary:' but start directly with the content.";

    // Append instruction to respond in the detected language, if not English
    if (detectedInputLanguageCode != 'en') { // 'en' is the language code for English
      String targetLanguageName = _convertLanguageCodeToName(detectedInputLanguageCode);
      if (targetLanguageName.isNotEmpty) {
        systemInstruction += " Respond *only* in $targetLanguageName.";
      }
    }

    conversationHistoryForAI.add({
      "role": "user",
      "parts": [
        {"text": systemInstruction}
      ]
    });

    // Add previous messages to the conversation history.
    // User messages from history will be translated to English for the AI's core processing,
    // assuming the Gemini model is primarily tuned for English input for reasoning.
    for (var msg in _messages) {
      String contentToSendToAI = msg['content'] as String;
      if (msg['role'] == 'user') {
        // Translate user input to English for AI comprehension, unless already English.
        // This is important because the core prompt to Gemini is in English, and its
        // understanding of history might be better if inputs are consistently English.
        if (await _detectLanguage(contentToSendToAI) != 'en') { // Use 'en' for language code check
          contentToSendToAI = await _translateText(contentToSendToAI, 'English');
        }
      }
      conversationHistoryForAI.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': contentToSendToAI},
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

        // Clean up special characters
        reply = reply.replaceAll('â', "'");
        reply = reply.replaceAll('â€œ', '“').replaceAll('â€ ', '”');
        reply = reply.replaceAll('â€™', '’');
        reply = reply.replaceAll('â€”', '—');
        reply = reply.replaceAll('â€“', '–');
        reply = reply.replaceAll('â€¦', '…');
        reply = reply.replaceAll(RegExp(r'[\uFFFD]'), '');

        // *** REMOVE THE FOLLOWING LINE:
        // if (_preferredLanguage != 'English') {
        //   reply = await _translateText(reply, _preferredLanguage); // Translate AI's reply back to preferred language
        // }
        // The AI is now instructed to respond in the detected language directly.

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
        // If an error occurs, consider translating the error message back to the detected input language
        String localizedErrorMessage = errorMessage;
        if (detectedInputLanguageCode != 'en') {
          localizedErrorMessage = await _translateText(errorMessage, _convertLanguageCodeToName(detectedInputLanguageCode));
        }

        final errorMessageData = {
          'role': 'assistant',
          'content': localizedErrorMessage,
          'timestamp': Timestamp.now(),
        };
        await _saveCurrentMessage(errorMessageData);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizedErrorMessage)),
          );
        }
      }
    } catch (e) {
      String errorMessage = 'Error processing y our request. Please try again later.';
      String localizedErrorMessage = errorMessage;
      if (detectedInputLanguageCode != 'en') {
        localizedErrorMessage = await _translateText(errorMessage, _convertLanguageCodeToName(detectedInputLanguageCode));
      }

      final errorMessageData = {
        'role': 'assistant',
        'content': localizedErrorMessage,
        'timestamp': Timestamp.now(),
      };
      await _saveCurrentMessage(errorMessageData);
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

  // Helper to convert language code to full language name (for Gemini prompt)
  String _convertLanguageCodeToName(String code) {
    switch (code) {
      case 'zh': return 'Chinese';
      case 'en': return 'English';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'ja': return 'Japanese';
      case 'ko': return 'Korean';
      case 'ar': return 'Arabic';
      case 'ru': return 'Russian';
      case 'pt': return 'Portuguese';
      case 'it': return 'Italian';
      case 'hi': return 'Hindi';
      case 'id': return 'Indonesian';
      case 'th': return 'Thai';
      case 'vi': return 'Vietnamese';
      case 'tr': return 'Turkish';
      case 'nl': return 'Dutch';
      case 'sv': return 'Swedish';
      case 'pl': return 'Polish';
      case 'da': return 'Danish';
      case 'fi': return 'Finnish';
      case 'no': return 'Norwegian';
      case 'el': return 'Greek';
      case 'he': return 'Hebrew';
      case 'hu': return 'Hungarian';
      case 'cs': return 'Czech';
      case 'sk': return 'Slovak';
      case 'ro': return 'Romanian';
      case 'bg': return 'Bulgarian';
      case 'uk': return 'Ukrainian';
      case 'hr': return 'Croatian';
      case 'fa': return 'Persian';
      case 'ur': return 'Urdu';
      case 'ms': return 'Malay';
      case 'fil': return 'Filipino'; // Tagalog
      case 'sw': return 'Swahili';
      case 'zu': return 'Zulu';
      case 'am': return 'Amharic';
      case 'bn': return 'Bengali';
      case 'gu': return 'Gujarati';
      case 'kn': return 'Kannada';
      case 'ml': return 'Malayalam';
      case 'mr': return 'Marathi';
      case 'pa': return 'Punjabi';
      case 'ta': return 'Tamil';
      case 'te': return 'Telugu';
      default: return ''; // Return empty string for unsupported or unknown languages
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

  // New function for language detection using Cloud Translation API
  Future<String> _detectLanguage(String text) async {
    if (_cloudTranslationApiKey.isEmpty) {
      return "en";
    }

    final url = Uri.parse('https://translation.googleapis.com/language/translate/v2/detect?key=$_cloudTranslationApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['detections'][0][0]['language'];
    } else {
      print('Language detection API error: ${response.body}');
      return "en";
    }
  }

  // Modified _translateText to use Cloud Translation API
  Future<String> _translateText(String text, String targetLanguageCode) async {
    if (_cloudTranslationApiKey.isEmpty || targetLanguageCode == 'en') {
      return text;
    }

    final url = Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$_cloudTranslationApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'target': targetLanguageCode,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['translations'][0]['translatedText'];
    } else {
      print('Translation API error: ${response.body}');
      return text;
    }
  }


  // Helper to convert language name (e.g., 'Chinese') to language code (e.g., 'zh')
  String _convertLanguageNameToCode(String name) {
    switch (name.toLowerCase()) {
      case 'chinese': return 'zh';
      case 'english': return 'en';
      case 'spanish': return 'es';
      case 'french': return 'fr';
      case 'german': return 'de';
      case 'japanese': return 'ja';
      case 'korean': return 'ko';
      case 'arabic': return 'ar';
      case 'russian': return 'ru';
      case 'portuguese': return 'pt';
      case 'italian': return 'it';
      case 'hindi': return 'hi';
      case 'indonesian': return 'id';
      case 'thai': return 'th';
      case 'vietnamese': return 'vi';
      case 'turkish': return 'tr';
      case 'dutch': return 'nl';
      case 'swedish': return 'sv';
      case 'polish': return 'pl';
      case 'danish': return 'da';
      case 'finnish': return 'fi';
      case 'norwegian': return 'no';
      case 'greek': return 'el';
      case 'hebrew': return 'he';
      case 'hungarian': return 'hu';
      case 'czech': return 'cs';
      case 'slovak': return 'sk';
      case 'romanian': return 'ro';
      case 'bulgarian': return 'bg';
      case 'ukrainian': return 'uk';
      case 'croatian': return 'hr';
      case 'persian': return 'fa';
      case 'urdu': return 'ur';
      case 'malay': return 'ms';
      case 'filipino': return 'fil';
      case 'swahili': return 'sw';
      case 'zulu': return 'zu';
      case 'amharic': return 'am';
      case 'bengali': return 'bn';
      case 'gujarati': return 'gu';
      case 'kannada': return 'kn';
      case 'malayalam': return 'ml';
      case 'marathi': return 'mr';
      case 'punjabi': return 'pa';
      case 'tamil': return 'ta';
      case 'telugu': return 'te';
      default: return ''; // Return empty string for unsupported or unknown language names
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
      // Replaced .withOpacity() with .withAlpha() or .withBlue() etc.
      // For this specific use case, .withAlpha() is a direct replacement for opacity.
      backgroundColor = _mediumPurple.withAlpha((255 * 0.3).round()); // Highlight other matches with a purple tint
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

  // Share entire conversation as text
  Future<void> _shareConversationAsText() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to share')),
      );
      return;
    }

    String conversationText = '🌍 Travel AI Chat Conversation\n';
    conversationText += '─' * 30 + '\n\n';

    for (var message in _messages) {
      final role = message['role'] == 'user' ? '👤 You' : '🤖 Travel AI';
      final content = message['content'] ?? '';
      final timestamp = (message['timestamp'] as Timestamp?)?.toDate();

      conversationText += '$role';
      if (timestamp != null) {
        conversationText += ' (${_formatDateTime(timestamp)})';
      }
      conversationText += ':\n$content\n\n';
    }

    conversationText += '─' * 30 + '\n';
    conversationText += 'Shared from Travel AI Assistant';

    await Share.share(
      conversationText,
      subject: 'My Travel AI Chat',
    );
  }

  // Share selected messages
  Future<void> _shareSelectedMessages(List<int> selectedIndices) async {
    if (selectedIndices.isEmpty) return;

    String selectedText = '🌍 Travel AI Chat Excerpt\n';
    selectedText += '─' * 30 + '\n\n';

    for (int index in selectedIndices) {
      if (index < _messages.length) {
        final message = _messages[index];
        final role = message['role'] == 'user' ? '👤 You' : '🤖 Travel AI';
        final content = message['content'] ?? '';

        selectedText += '$role:\n$content\n\n';
      }
    }

    selectedText += '─' * 30 + '\n';
    selectedText += 'Shared from Travel AI Assistant';

    await Share.share(selectedText);
  }

  // Share conversation as image
  Future<void> _shareConversationAsImage() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to share')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Capture the conversation as image
      final RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Save image to temporary directory
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/travel_chat_${DateTime.now().millisecondsSinceEpoch}.png')
            .create();
        await file.writeAsBytes(pngBytes);

        // Close loading dialog
        Navigator.pop(context);

        // Share the image
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '🌍 Check out my Travel AI conversation!',
          subject: 'Travel AI Chat',
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    }
  }

  // Share last travel recommendation
  Future<void> _shareLastTravelRecommendation() async {
    // Find the last assistant message with travel content
    Map<String, dynamic>? lastRecommendation;

    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['role'] == 'assistant') {
        final content = _messages[i]['content'] ?? '';
        // Check if it contains travel-related content
        if (_containsTravelContent(content)) {
          lastRecommendation = _messages[i];
          break;
        }
      }
    }

    if (lastRecommendation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No travel recommendations to share')),
      );
      return;
    }

    final content = lastRecommendation['content'] ?? '';
    final shareText = '🌍 Travel Recommendation from AI Assistant:\n\n$content\n\n'
        '─' * 30 + '\nGet personalized travel advice with Travel AI!';

    await Share.share(
      shareText,
      subject: 'Travel Recommendation',
    );
  }

  bool _containsTravelContent(String content) {
    final lowerContent = content.toLowerCase();
    return _travelKeywords.any((keyword) => lowerContent.contains(keyword));
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Show share options bottom sheet
  void _showShareOptions() {
    setState(() {
      _isShareMenuOpen = true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Share Conversation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkPurple,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.text_fields, color: _mediumPurple),
                title: const Text('Share as Text'),
                subtitle: const Text('Share entire conversation as text'),
                onTap: () {
                  Navigator.pop(context);
                  _shareConversationAsText();
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: _mediumPurple),
                title: const Text('Share as Image'),
                subtitle: const Text('Create and share a screenshot'),
                onTap: () {
                  Navigator.pop(context);
                  _shareConversationAsImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.recommend, color: _mediumPurple),
                title: const Text('Share Last Recommendation'),
                subtitle: const Text('Share the latest travel advice'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLastTravelRecommendation();
                },
              ),
              ListTile(
                leading: Icon(Icons.select_all, color: _mediumPurple),
                title: const Text('Select Messages to Share'),
                subtitle: const Text('Choose specific messages'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageSelection();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    ).whenComplete(() {
      setState(() {
        _isShareMenuOpen = false;
      });
    });
  }

  // Show message selection dialog
  void _showMessageSelection() {
    List<int> selectedIndices = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Select Messages to Share',
                style: TextStyle(color: _darkPurple),
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message['role'] == 'user';
                    final content = message['content'] ?? '';
                    final truncatedContent = content.length > 50
                        ? '${content.substring(0, 50)}...'
                        : content;

                    return CheckboxListTile(
                      value: selectedIndices.contains(index),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedIndices.add(index);
                          } else {
                            selectedIndices.remove(index);
                          }
                        });
                      },
                      title: Text(
                        isUser ? '👤 You' : '🤖 Travel AI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUser ? _darkPurple : _mediumPurple,
                        ),
                      ),
                      subtitle: Text(truncatedContent),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedIndices.isEmpty
                      ? null
                      : () {
                    Navigator.pop(context);
                    _shareSelectedMessages(selectedIndices);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkPurple,
                  ),
                  child: Text(
                    'Share (${selectedIndices.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
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
            icon: Icon(Icons.share, color: _darkPurple),
            onPressed: _messages.isEmpty ? null : _showShareOptions,
            tooltip: 'Share Conversation',
          ),
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
              child: RepaintBoundary(
                key: _repaintBoundaryKey,
                child: Container(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i], i),
                  ),
                ),
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
                            // Replaced .withOpacity() with .withAlpha()
                            color: _mediumPurple.withAlpha((255 * 0.4).round()),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            // Replaced .withOpacity() with .withAlpha()
                            color: _mediumPurple.withAlpha((255 * 0.4).round()),
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
                        // Replaced .withOpacity() with .withAlpha()
                        fillColor: _lightBeige.withAlpha((255 * 0.6).round()),
                        filled: true,
                        hintStyle: TextStyle(
                          // Replaced .withOpacity() with .withAlpha()
                          color: _greyText.withAlpha((255 * 0.6).round()),
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