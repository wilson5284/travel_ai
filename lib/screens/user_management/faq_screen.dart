import 'package:flutter/material.dart';
import 'package:travel_ai/screens/chatbot_screen.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Color scheme (copied from your existing code for consistency)
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _lightBeige = const Color(0xFFFFF5E6);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
      final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _redEmergency = Colors.red.shade700; // From emergency_screen for consistent action color

  // Static FAQ list (could be loaded from Firestore or JSON later)
  final List<Map<String, String>> allFAQs = [
    {
      'question': 'How do I create a trip?',
      'answer': 'Tap on "Create Trip", fill in your preferences, and submit. Our AI will help generate your perfect itinerary.'
    },
    {
      'question': 'Can I modify my trip after saving?',
      'answer': 'Yes, go to My Trips > Tap the trip you wish to modify > You can then adjust details like dates, destinations, or activities.'
    },
    {
      'question': 'How is the weather shown?',
      'answer': 'Weather information is pulled from a real-time weather API during itinerary generation to provide you with the most current forecast for your travel dates.'
    },
    {
      'question': 'Can I export my trip to PDF?',
      'answer': 'Absolutely! Tap the "Share PDF" button located inside the trip detail page to generate a printable itinerary.'
    },
    {
      'question': 'Is an account required to use the app?',
      'answer': 'Yes, you must be logged in to access features like creating, saving, and managing your personalized trips.'
    },
    {
      'question': 'What kind of travel tips are available?',
      'answer': 'Our travel tips cover a wide range of topics including local customs, safety advice, transportation options, and food recommendations specific to your destination.'
    },
    {
      'question': 'How do I contact customer support?',
      'answer': 'If your question isn\'t answered here, you can use the "Ask Admin" button to send us an email, or "Open Chatbot" to get instant assistance from our AI.'
    },
    {
      'question': 'Is this app free to use?',
      'answer': 'Yes, the core features of this app, including trip planning and emergency contacts, are completely free to download and use. There are no hidden charges or subscriptions.'
    },
  ];

  List<Map<String, String>> filteredFAQs = [];

  @override
  void initState() {
    super.initState();
    filteredFAQs = allFAQs;
  }

  void _searchFAQs(String query) {
    setState(() {
      filteredFAQs = allFAQs.where((faq) {
        return faq['question']!.toLowerCase().contains(query.toLowerCase()) ||
            faq['answer']!.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _askAdmin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white, // Consistent background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Contact Support', style: TextStyle(color: _darkPurple)),
        content: Text(
          'This feature will open your email client to send a message to our support team. Please ensure you have an email app configured.',
          style: TextStyle(color: _greyText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _mediumPurple)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening email client... (Functionality not yet implemented)')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _redEmergency, // Consistent action color
              foregroundColor: _white,
            ),
            child: const Text('Proceed'),
          )
        ],
      ),
    );
  }

  void _openChatbot() {
    // Correctly navigate using MaterialPageRoute for better control and consistency
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotScreen()),
    );
  }

  // Helper for consistent Input Decoration
  InputDecoration _buildInputDecoration(String labelText, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: _darkPurple.withOpacity(0.8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _mediumPurple) : null,
      filled: true,
      fillColor: _lightBeige.withOpacity(0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _mediumPurple.withOpacity(0.4), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _mediumPurple.withOpacity(0.4), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkPurple, width: 2.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ & Help'),
        backgroundColor: _darkPurple, // Consistent AppBar background
        foregroundColor: _white, // Consistent AppBar text color
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lightPurple, // Light violet
              _lightBeige,  // Light beige
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24), // Consistent padding from other screens
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align content to start
            children: [
              Text(
                'Got Questions? We\'ve Got Answers!',
                style: TextStyle(
                  fontSize: 24, // Slightly larger for section title
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find quick answers to common questions about using our app.',
                style: TextStyle(
                  fontSize: 15,
                  color: _greyText,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                decoration: _buildInputDecoration('Search FAQ...', prefixIcon: Icons.search), // Apply consistent input decoration
                style: TextStyle(color: _darkPurple), // Text color inside input
                onChanged: _searchFAQs,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredFAQs.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sentiment_dissatisfied, size: 50, color: _mediumPurple),
                      const SizedBox(height: 10),
                      Text(
                        'No matching FAQs found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _greyText, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Try a different search or use the options below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _greyText, fontSize: 14),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: filteredFAQs.length,
                  itemBuilder: (context, index) {
                    final faq = filteredFAQs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 3, // Consistent elevation
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)), // Rounded corners
                      child: Theme( // Hides the default divider
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: _mediumPurple,
                          collapsedIconColor: _mediumPurple,
                          textColor: _darkPurple,
                          collapsedTextColor: _darkPurple,
                          backgroundColor: _offWhite, // Background color when expanded
                          collapsedBackgroundColor: _white, // Background color when collapsed
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15), // Consistent shape
                          ),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          title: Text(
                            faq['question']!,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _darkPurple), // Consistent text style
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Text(
                                faq['answer']!,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: _greyText), // Consistent text style
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24), // Spacing before action buttons
              Text(
                'Still can\'t find what you\'re looking for?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _darkPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.email_outlined), // Changed icon for email
                      onPressed: _askAdmin,
                      label: const Text('Ask Admin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redEmergency, // Consistent action color (e.g., emergency red)
                        foregroundColor: _white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16), // Slightly smaller for 2 buttons
                        elevation: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline), // Consistent chat icon
                      onPressed: _openChatbot,
                      label: const Text('Open Chatbot'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mediumPurple, // Consistent button color
                        foregroundColor: _white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                        elevation: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}