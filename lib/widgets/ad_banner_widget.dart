// lib/widgets/ad_banner_widget.dart - FIXED VERSION WITH PROPER CLICK HANDLING
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdBannerWidget extends StatefulWidget {
  final String position; // 'top', 'middle', 'bottom'
  final EdgeInsets? margin;
  final double? height;

  const AdBannerWidget({
    super.key,
    required this.position,
    this.margin,
    this.height,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  DocumentSnapshot? _activeBanner;
  bool _isLoading = true;
  bool _hasTrackedImpression = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    try {
      print('🔍 Loading banner for position: ${widget.position}');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ad_banners')
          .where('position', isEqualTo: widget.position)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _activeBanner = querySnapshot.docs.first;
          _isLoading = false;
        });

        print('✅ Banner loaded for position: ${widget.position}');
        // Track impression when banner loads and becomes visible
        _trackImpression();
      } else {
        setState(() {
          _isLoading = false;
        });
        print('❌ No active banner found for position: ${widget.position}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ Error loading banner: $e');
    }
  }

  Future<void> _trackImpression() async {
    if (_activeBanner != null && !_hasTrackedImpression) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final now = Timestamp.now();

        // Update banner impression count
        await FirebaseFirestore.instance
            .collection('ad_banners')
            .doc(_activeBanner!.id)
            .update({
          'impressions': FieldValue.increment(1),
          'lastImpression': now,
        });

        // FIXED: Use consistent field name 'type' instead of 'action'
        await FirebaseFirestore.instance
            .collection('banner_analytics')
            .add({
          'bannerId': _activeBanner!.id,
          'type': 'impression', // FIXED: Changed from 'action' to 'type'
          'timestamp': now,
          'position': widget.position,
          'userId': currentUser?.uid,
          'userAgent': 'Flutter App',
        });

        _hasTrackedImpression = true;
        print('✅ Banner impression tracked for position: ${widget.position}');
      } catch (e) {
        print('❌ Error tracking impression: $e');
      }
    }
  }

  Future<void> _trackClick() async {
    if (_activeBanner != null) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final now = Timestamp.now();

        print('🖱️ Tracking click for banner: ${_activeBanner!.id}');

        // Update banner click count
        await FirebaseFirestore.instance
            .collection('ad_banners')
            .doc(_activeBanner!.id)
            .update({
          'clicks': FieldValue.increment(1),
          'lastClick': now,
        });

        // FIXED: Use consistent field name 'type' instead of 'action'
        await FirebaseFirestore.instance
            .collection('banner_analytics')
            .add({
          'bannerId': _activeBanner!.id,
          'type': 'click', // FIXED: Changed from 'action' to 'type'
          'timestamp': now,
          'position': widget.position,
          'userId': currentUser?.uid,
          'userAgent': 'Flutter App',
        });

        print('✅ Banner click tracked for position: ${widget.position}');
      } catch (e) {
        print('❌ Error tracking click: $e');
      }
    }
  }

  Future<void> _handleBannerTap(String actionUrl) async {
    print('🎯 Banner tapped! URL: $actionUrl');

    // Show user feedback immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening advertisement...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Track the click first
    await _trackClick();

    // Enhanced URL handling with multiple fallback options
    await _openUrl(actionUrl);
  }

  Future<void> _openUrl(String url) async {
    try {
      // Clean and validate the URL
      String cleanUrl = url.trim();

      // Add https:// if no protocol is specified
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
        print('🔧 Added https:// to URL: $cleanUrl');
      }

      final uri = Uri.parse(cleanUrl);
      print('🌐 Attempting to launch URL: $cleanUrl');

      // Validate the URL format
      if (!uri.hasScheme || uri.host.isEmpty) {
        print('❌ Invalid URL format: $cleanUrl');
        _showErrorSnackBar('Invalid link format');
        return;
      }

      // Try multiple launch modes in order of preference
      final launchModes = [
        LaunchMode.externalApplication,
        LaunchMode.externalNonBrowserApplication,
        LaunchMode.platformDefault,
      ];

      bool launched = false;

      for (final mode in launchModes) {
        try {
          print('🚀 Trying launch mode: $mode');

          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(uri, mode: mode);

            if (launched) {
              print('✅ URL launched successfully with mode: $mode');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Link opened successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
              break;
            }
          }
        } catch (e) {
          print('❌ Failed with mode $mode: $e');
          continue;
        }
      }

      if (!launched) {
        print('❌ All launch methods failed for URL: $cleanUrl');
        _showErrorSnackBar('Cannot open this link. Please check your device settings.');
      }

    } catch (e) {
      print('❌ Error parsing/opening URL: $e');
      _showErrorSnackBar('Invalid link format: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height ?? 100,
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_activeBanner == null) {
      // No banner to show - return empty space
      return const SizedBox.shrink();
    }

    final bannerData = _activeBanner!.data() as Map<String, dynamic>;
    final title = bannerData['title'] ?? '';
    final imageUrl = bannerData['imageUrl'] ?? '';
    final actionUrl = bannerData['actionUrl'] ?? '';
    final description = bannerData['description'] ?? '';

    return Container(
      height: widget.height ?? 100,
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(15),
        shadowColor: Colors.purple.withValues(alpha: 0.2),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: actionUrl.isNotEmpty ? () {
            print('🎯 InkWell tapped for banner: $title');
            _handleBannerTap(actionUrl);
          } : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.purple.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  // Banner Image
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.purple.shade100,
                                Colors.purple.shade50,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.ad_units,
                                  color: Colors.purple.shade300, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                title.isNotEmpty ? title : 'Advertisement',
                                style: TextStyle(
                                  color: Colors.purple.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.purple.shade400,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade100,
                                Colors.grey.shade50,
                              ],
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade300),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Overlay with text (if banner has content)
                  if (title.isNotEmpty || description.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title.isNotEmpty)
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // "Ad" indicator in top-right corner
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Ad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Tap indicator - subtle visual feedback
                  if (actionUrl.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: Colors.purple.shade600,
                        ),
                      ),
                    ),

                  // ADDED: Full overlay to ensure clicks are captured
                  if (actionUrl.isNotEmpty)
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            print('🎯 Overlay tapped for banner: $title');
                            _handleBannerTap(actionUrl);
                          },
                          splashColor: Colors.white.withValues(alpha: 0.2),
                          highlightColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}