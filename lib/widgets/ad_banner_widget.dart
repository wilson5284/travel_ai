// lib/widgets/ad_banner_widget.dart - MATCHES YOUR EXISTING IMPORT
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

        // Track impression when banner loads and becomes visible
        _trackImpression();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading banner: $e');
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

        // Log detailed analytics for tracking
        await FirebaseFirestore.instance
            .collection('banner_analytics')
            .add({
          'bannerId': _activeBanner!.id,
          'type': 'impression',
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

        // Update banner click count
        await FirebaseFirestore.instance
            .collection('ad_banners')
            .doc(_activeBanner!.id)
            .update({
          'clicks': FieldValue.increment(1),
          'lastClick': now,
        });

        // Log detailed analytics for tracking
        await FirebaseFirestore.instance
            .collection('banner_analytics')
            .add({
          'bannerId': _activeBanner!.id,
          'type': 'click',
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
    // Track the click first
    await _trackClick();

    // Then open the URL
    try {
      final uri = Uri.parse(actionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Cannot launch URL: $actionUrl');
      }
    } catch (e) {
      print('Error opening URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height ?? 100,
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        shadowColor: Colors.purple.withValues(alpha: 0.2),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: actionUrl.isNotEmpty ? () => _handleBannerTap(actionUrl) : null,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}