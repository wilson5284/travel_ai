// lib/utils/social_sharing_utils.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialSharingUtils {
  static const String _appName = 'TravelAI';
  static const String _appHashtag = '#TravelAI';
  static const String _appUrl = 'https://yourapp.com'; // Replace with your app URL

  // Enhanced sharing with platform-specific formatting
  static Future<void> shareToSpecificPlatform({
    required String content,
    required SocialPlatform platform,
    String? subject,
  }) async {
    String formattedContent = _formatContentForPlatform(content, platform);

    switch (platform) {
      case SocialPlatform.twitter:
        await _shareToTwitter(formattedContent);
        break;
      case SocialPlatform.facebook:
        await _shareToFacebook(formattedContent);
        break;
      case SocialPlatform.instagram:
        await _shareToInstagram(formattedContent);
        break;
      case SocialPlatform.whatsapp:
        await _shareToWhatsApp(formattedContent);
        break;
      case SocialPlatform.linkedin:
        await _shareToLinkedIn(formattedContent);
        break;
      case SocialPlatform.telegram:
        await _shareToTelegram(formattedContent);
        break;
      case SocialPlatform.generic:
        await Share.share(formattedContent, subject: subject);
        break;
    }
  }

  static String _formatContentForPlatform(String content, SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.twitter:
        return _formatForTwitter(content);
      case SocialPlatform.facebook:
        return _formatForFacebook(content);
      case SocialPlatform.instagram:
        return _formatForInstagram(content);
      case SocialPlatform.whatsapp:
        return _formatForWhatsApp(content);
      case SocialPlatform.linkedin:
        return _formatForLinkedIn(content);
      case SocialPlatform.telegram:
        return _formatForTelegram(content);
      case SocialPlatform.generic:
        return content;
    }
  }

  static String _formatForTwitter(String content) {
    // Twitter has character limit, so we need to be concise
    String twitterContent = content;
    if (content.length > 240) { // Leave space for hashtags and URL
      twitterContent = '${content.substring(0, 200)}... ';
    }
    twitterContent += '\n\n$_appHashtag #TravelPlanning #AI';
    return twitterContent;
  }

  static String _formatForFacebook(String content) {
    String facebookContent = content;
    facebookContent += '\n\n';
    facebookContent += '✈️ Shared from $_appName - Your Smart Travel Companion\n';
    facebookContent += '$_appHashtag #TravelPlanning #SmartTravel #AI\n';
    facebookContent += '\nDownload $_appName: $_appUrl';
    return facebookContent;
  }

  static String _formatForInstagram(String content) {
    // Instagram is more visual, so we create hashtag-rich content
    String instagramContent = content;
    instagramContent += '\n\n';
    instagramContent += '✈️🤖 Planning made easy with $_appName!\n\n';
    instagramContent += '$_appHashtag #TravelPlanning #AI #SmartTravel #TravelTips ';
    instagramContent += '#Wanderlust #TravelAddict #ExploreMore #TravelTech #Vacation';
    return instagramContent;
  }

  static String _formatForWhatsApp(String content) {
    String whatsappContent = '🤖 *$_appName Travel Advice* 🤖\n\n';
    whatsappContent += content;
    whatsappContent += '\n\n_Shared from $_appName - Your Smart Travel Companion_\n';
    whatsappContent += '$_appUrl';
    return whatsappContent;
  }

  static String _formatForLinkedIn(String content) {
    String linkedinContent = '🚀 Leveraging AI for Smart Travel Planning\n\n';
    linkedinContent += content;
    linkedinContent += '\n\n$_appName is revolutionizing how we plan our travels with AI-powered recommendations.\n\n';
    linkedinContent += '$_appHashtag #ArtificialIntelligence #TravelTech #Innovation #TravelPlanning';
    return linkedinContent;
  }

  static String _formatForTelegram(String content) {
    String telegramContent = '🤖 *TravelAI Conversation*\n\n';
    telegramContent += content;
    telegramContent += '\n\n✈️ Get smart travel advice: $_appUrl\n';
    telegramContent += '$_appHashtag';
    return telegramContent;
  }

  // Platform-specific sharing methods
  static Future<void> _shareToTwitter(String content) async {
    final encodedContent = Uri.encodeComponent(content);
    final url = 'https://twitter.com/intent/tweet?text=$encodedContent';
    await _launchUrl(url);
  }

  static Future<void> _shareToFacebook(String content) async {
    final encodedContent = Uri.encodeComponent(content);
    final url = 'https://www.facebook.com/sharer/sharer.php?u=$_appUrl&quote=$encodedContent';
    await _launchUrl(url);
  }

  static Future<void> _shareToInstagram(String content) async {
    // Instagram doesn't support direct text sharing via URL, fallback to generic share
    await Share.share(content);
  }

  static Future<void> _shareToWhatsApp(String content) async {
    final encodedContent = Uri.encodeComponent(content);
    final url = 'https://wa.me/?text=$encodedContent';
    await _launchUrl(url);
  }

  static Future<void> _shareToLinkedIn(String content) async {
    final encodedContent = Uri.encodeComponent(content);
    final encodedUrl = Uri.encodeComponent(_appUrl);
    final url = 'https://www.linkedin.com/sharing/share-offsite/?url=$encodedUrl&summary=$encodedContent';
    await _launchUrl(url);
  }

  static Future<void> _shareToTelegram(String content) async {
    final encodedContent = Uri.encodeComponent(content);
    final url = 'https://t.me/share/url?url=$_appUrl&text=$encodedContent';
    await _launchUrl(url);
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $url');
    }
  }

  // Create conversation summaries for sharing
  static String createConversationSummary(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return '';

    String summary = '🤖 $_appName helped me plan my trip!\n\n';

    // Find the main travel topic
    String travelTopic = _extractTravelTopic(messages);
    if (travelTopic.isNotEmpty) {
      summary += '📍 Topic: $travelTopic\n\n';
    }

    // Get key insights from AI responses
    List<String> keyInsights = _extractKeyInsights(messages);
    if (keyInsights.isNotEmpty) {
      summary += '💡 Key insights:\n';
      for (int i = 0; i < keyInsights.length && i < 3; i++) {
        summary += '• ${keyInsights[i]}\n';
      }
      summary += '\n';
    }

    summary += '✈️ Get personalized travel advice with $_appName!\n';
    summary += '$_appHashtag #TravelPlanning #AI';

    return summary;
  }

  static String _extractTravelTopic(List<Map<String, dynamic>> messages) {
    // Extract main travel destination or topic from messages
    final userMessages = messages.where((msg) => msg['role'] == 'user').toList();
    if (userMessages.isEmpty) return '';

    String firstMessage = userMessages.first['content'] as String? ?? '';

    // Simple keyword extraction for travel topics
    final travelKeywords = {
      'paris': 'Paris',
      'tokyo': 'Tokyo',
      'london': 'London',
      'new york': 'New York',
      'bali': 'Bali',
      'thailand': 'Thailand',
      'italy': 'Italy',
      'spain': 'Spain',
      'japan': 'Japan',
      'greece': 'Greece',
      'flight': 'Flight booking',
      'hotel': 'Accommodation',
      'visa': 'Visa requirements',
      'itinerary': 'Trip planning',
      'budget': 'Budget travel',
    };

    String lowerMessage = firstMessage.toLowerCase();
    for (var entry in travelKeywords.entries) {
      if (lowerMessage.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Travel planning';
  }

  static List<String> _extractKeyInsights(List<Map<String, dynamic>> messages) {
    List<String> insights = [];

    final aiMessages = messages
        .where((msg) => msg['role'] == 'assistant')
        .toList();

    for (var message in aiMessages) {
      String content = message['content'] as String? ?? '';

      // Extract bullet points or numbered lists
      final lines = content.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
          String insight = line.replaceFirst(RegExp(r'^[•\-*]\s*'), '');
          if (insight.length > 20 && insight.length < 100) {
            insights.add(insight);
          }
        }
      }

      if (insights.length >= 5) break; // Limit insights
    }

    return insights;
  }

  // Analytics for shared content
  static Future<void> trackSharingEvent({
    required String userId,
    required SocialPlatform platform,
    required String contentType,
    int? messageCount,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('sharing_analytics')
          .add({
        'userId': userId,
        'platform': platform.name,
        'contentType': contentType,
        'messageCount': messageCount,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking sharing event: $e');
    }
  }

  // Generate sharing templates
  static List<SharingTemplate> getSharingTemplates() {
    return [
      SharingTemplate(
        title: 'Quick Update',
        icon: Icons.flash_on,
        description: 'Share a quick post about your TravelAI experience',
        template: '🤖 Just got amazing travel advice from $_appName! {topic} ✈️🌍\n\n$_appHashtag #TravelPlanning #AITravel',
      ),
      SharingTemplate(
        title: 'Detailed Experience',
        icon: Icons.article,
        description: 'Share your full conversation summary',
        template: '🤖 $_appName helped me plan the perfect trip!\n\n{summary}\n\n✈️ Get smart travel advice: $_appUrl\n$_appHashtag',
      ),
      SharingTemplate(
        title: 'Travel Tip',
        icon: Icons.lightbulb,
        description: 'Share a specific travel tip you learned',
        template: '💡 Travel Tip from $_appName:\n\n{tip}\n\nWhat travel challenges can AI help you solve? ✈️\n$_appHashtag #TravelTips',
      ),
      SharingTemplate(
        title: 'Recommendation',
        icon: Icons.thumb_up,
        description: 'Recommend TravelAI to friends',
        template: '🚀 Discovered an amazing AI travel assistant! $_appName helps with everything from flights to itineraries.\n\n{experience}\n\nTry it: $_appUrl\n$_appHashtag',
      ),
    ];
  }
}

enum SocialPlatform {
  twitter,
  facebook,
  instagram,
  whatsapp,
  linkedin,
  telegram,
  generic,
}

class SharingTemplate {
  final String title;
  final IconData icon;
  final String description;
  final String template;

  SharingTemplate({
    required this.title,
    required this.icon,
    required this.description,
    required this.template,
  });
}

// Extension for easy platform identification
extension SocialPlatformExtension on SocialPlatform {
  String get displayName {
    switch (this) {
      case SocialPlatform.twitter:
        return 'Twitter';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.whatsapp:
        return 'WhatsApp';
      case SocialPlatform.linkedin:
        return 'LinkedIn';
      case SocialPlatform.telegram:
        return 'Telegram';
      case SocialPlatform.generic:
        return 'More options';
    }
  }

  IconData get icon {
    switch (this) {
      case SocialPlatform.twitter:
        return Icons.flutter_dash; // Use appropriate icon
      case SocialPlatform.facebook:
        return Icons.facebook;
      case SocialPlatform.instagram:
        return Icons.camera_alt;
      case SocialPlatform.whatsapp:
        return Icons.message;
      case SocialPlatform.linkedin:
        return Icons.business;
      case SocialPlatform.telegram:
        return Icons.send;
      case SocialPlatform.generic:
        return Icons.share;
    }
  }

  Color get color {
    switch (this) {
      case SocialPlatform.twitter:
        return const Color(0xFF1DA1F2);
      case SocialPlatform.facebook:
        return const Color(0xFF1877F2);
      case SocialPlatform.instagram:
        return const Color(0xFFE4405F);
      case SocialPlatform.whatsapp:
        return const Color(0xFF25D366);
      case SocialPlatform.linkedin:
        return const Color(0xFF0A66C2);
      case SocialPlatform.telegram:
        return const Color(0xFF0088CC);
      case SocialPlatform.generic:
        return Colors.grey;
    }
  }
}