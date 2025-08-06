// lib/widgets/social_sharing_widget.dart
import 'package:flutter/material.dart';
import '../utils/social_sharing_utils.dart';

class SocialSharingWidget extends StatefulWidget {
  final String content;
  final List<Map<String, dynamic>>? messages;
  final String? userId;
  final VoidCallback? onSharingComplete;

  const SocialSharingWidget({
    super.key,
    required this.content,
    this.messages,
    this.userId,
    this.onSharingComplete,
  });

  @override
  State<SocialSharingWidget> createState() => _SocialSharingWidgetState();
}

class _SocialSharingWidgetState extends State<SocialSharingWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SharingTemplate? _selectedTemplate;
  SocialPlatform? _selectedPlatform;

  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _lightPurple,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.share, color: _darkPurple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Share Your Travel Experience',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkPurple,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: _darkPurple),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: _darkPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _mediumPurple,
            tabs: const [
              Tab(text: 'Quick Share', icon: Icon(Icons.flash_on)),
              Tab(text: 'Templates', icon: Icon(Icons.article)),
              Tab(text: 'Platforms', icon: Icon(Icons.apps)),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuickShareTab(),
                _buildTemplatesTab(),
                _buildPlatformsTab(),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _darkPurple,
                      side: BorderSide(color: _darkPurple),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mediumPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShareTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick sharing options for your travel conversation:',
            style: TextStyle(fontSize: 16, color: _darkPurple),
          ),
          const SizedBox(height: 20),

          // Quick share cards
          _buildQuickShareCard(
            title: 'Share Conversation Summary',
            subtitle: 'Share highlights from your chat',
            icon: Icons.summarize,
            onTap: () => _shareConversationSummary(),
          ),

          _buildQuickShareCard(
            title: 'Share as Travel Tip',
            subtitle: 'Share specific advice you received',
            icon: Icons.lightbulb,
            onTap: () => _shareAsTravelTip(),
          ),

          _buildQuickShareCard(
            title: 'Recommend TravelAI',
            subtitle: 'Tell others about the app',
            icon: Icons.thumb_up,
            onTap: () => _shareRecommendation(),
          ),

          const Spacer(),

          // Platform selection for quick share
          Text(
            'Choose platform:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _darkPurple),
          ),
          const SizedBox(height: 10),
          _buildPlatformGrid(isCompact: true),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    final templates = SocialSharingUtils.getSharingTemplates();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a template for your post:',
            style: TextStyle(fontSize: 16, color: _darkPurple),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final isSelected = _selectedTemplate == template;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? _mediumPurple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? _mediumPurple : _lightPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        template.icon,
                        color: isSelected ? Colors.white : _darkPurple,
                      ),
                    ),
                    title: Text(
                      template.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _darkPurple,
                      ),
                    ),
                    subtitle: Text(template.description),
                    onTap: () {
                      setState(() {
                        _selectedTemplate = template;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your preferred platform:',
            style: TextStyle(fontSize: 16, color: _darkPurple),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildPlatformGrid(isCompact: false),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShareCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _lightPurple,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _darkPurple),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _darkPurple)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _mediumPurple),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPlatformGrid({required bool isCompact}) {
    final platforms = [
      SocialPlatform.whatsapp,
      SocialPlatform.twitter,
      SocialPlatform.facebook,
      SocialPlatform.instagram,
      SocialPlatform.linkedin,
      SocialPlatform.telegram,
      SocialPlatform.generic,
    ];

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 4 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isCompact ? 1 : 0.8,
      ),
      itemCount: platforms.length,
      itemBuilder: (context, index) {
        final platform = platforms[index];
        final isSelected = _selectedPlatform == platform;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlatform = platform;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? platform.color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? platform.color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? platform.color : platform.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    platform.icon,
                    color: isSelected ? Colors.white : platform.color,
                    size: isCompact ? 20 : 24,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(height: 8),
                  Text(
                    platform.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? platform.color : _darkPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareConversationSummary() {
    if (widget.messages != null) {
      final summary = SocialSharingUtils.createConversationSummary(widget.messages!);
      _shareContent(summary, 'conversation_summary');
    } else {
      _shareContent(widget.content, 'conversation_summary');
    }
  }

  void _shareAsTravelTip() {
    String tipContent = '💡 Travel Tip from TravelAI:\n\n${widget.content}\n\n';
    tipContent += 'What travel challenges can AI help you solve? ✈️\n#TravelAI #TravelTips';
    _shareContent(tipContent, 'travel_tip');
  }

  void _shareRecommendation() {
    String recommendation = '🚀 Discovered an amazing AI travel assistant! ';
    recommendation += 'TravelAI helps with everything from flights to itineraries.\n\n';
    recommendation += '${widget.content}\n\n';
    recommendation += 'Try it: https://yourapp.com\n#TravelAI #TravelPlanning #AI';
    _shareContent(recommendation, 'recommendation');
  }

  void _handleShare() {
    if (_selectedTemplate != null) {
      String templateContent = _selectedTemplate!.template;
      // Replace placeholders in template
      templateContent = templateContent.replaceAll('{topic}', 'Amazing travel planning!');
      templateContent = templateContent.replaceAll('{summary}', widget.content);
      templateContent = templateContent.replaceAll('{tip}', widget.content);
      templateContent = templateContent.replaceAll('{experience}', widget.content);

      _shareContent(templateContent, 'template_${_selectedTemplate!.title.toLowerCase()}');
    } else {
      _shareContent(widget.content, 'custom');
    }
  }

  void _shareContent(String content, String contentType) async {
    final platform = _selectedPlatform ?? SocialPlatform.generic;

    try {
      await SocialSharingUtils.shareToSpecificPlatform(
        content: content,
        platform: platform,
        subject: 'TravelAI Experience',
      );

      // Track sharing analytics
      if (widget.userId != null) {
        await SocialSharingUtils.trackSharingEvent(
          userId: widget.userId!,
          platform: platform,
          contentType: contentType,
          messageCount: widget.messages?.length,
        );
      }

      if (widget.onSharingComplete != null) {
        widget.onSharingComplete!();
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shared to ${platform.displayName}!'),
          backgroundColor: platform.color,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}