import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String _preferredLanguage = 'English';

  static const String deepSeekKey = 'sk-7f50d215dd784f7a82a12212c8802525';

  @override
  void initState() {
    super.initState();
    _loadUserPreferredLanguage();
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

  Future<void> _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    // Basic travel-related topic filter
    final travelKeywords = [
      'travel', 'trip', 'tour', 'visa', 'flight', 'hotel',
      'weather', 'place', 'destination', 'recommend', 'itinerary',
      'currency', 'transport', 'passport', 'booking', 'journey',
      'tourism', 'location', 'stay', 'holiday', 'schedule', 'luggage'
    ];
    final lowerInput = userInput.toLowerCase();
    final isTravelQuestion = travelKeywords.any((kw) => lowerInput.contains(kw));

    if (!isTravelQuestion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗️This chatbot is designed to answer travel-related questions only.')),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': userInput});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

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
          "content":
          "You are a helpful travel assistant. Always answer questions about travel, tourism, places, itineraries, safety, visas, transportation, languages, and culture. Reply in clean, friendly sentences with proper formatting and no markdown."
        },
        ..._messages
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
        String reply = data['choices'][0]['message']['content'];
        reply = _formatResponse(reply);

        if (_preferredLanguage != 'English') {
          reply = await _translateText(reply, _preferredLanguage);
        }

        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI did not return a response.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<String> _translateText(String text, String language) async {
    final url = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $deepSeekKey',
    };
    final body = json.encode({
      "model": "deepseek-chat",
      "messages": [
        {"role": "system", "content": "Translate the following into $language."},
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
        return data['choices'][0]['message']['content'] ?? text;
      } else {
        return text;
      }
    } catch (e) {
      print('Translation error: $e');
      return text;
    }
  }

  String _formatResponse(String raw) {
    return raw
    // Remove markdown and special formatting characters
        .replaceAll(RegExp(r'[\*#`>\[\]_~\|]'), '')
    // Remove non-printable ASCII (excluding newline)
        .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
    // Collapse multiple newlines into one
        .replaceAll(RegExp(r'\n{2,}'), '\n')
    // Format list items to use proper bullets
        .replaceAll(RegExp(r'\n-'), '\n•')
    // Trim whitespace
        .trim();
  }


  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildMessage(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg['content'] ?? '',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel AI Chat"),
        automaticallyImplyLeading: false,
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
              child: CircularProgressIndicator(),
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
                      hintText: 'Ask about flights, places, visas...'
                          ' (e.g., What’s the weather in Tokyo?)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}
