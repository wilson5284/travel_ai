// lib/admin/banner_management_screen.dart - UPDATED WITH EDIT/DELETE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'banner_analytics_screen.dart'; // Add this import

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  Future<void> _showAddBannerDialog([DocumentSnapshot? bannerDoc]) async {
    final isEditing = bannerDoc != null;
    final bannerData = bannerDoc?.data() as Map<String, dynamic>?;

    final titleController = TextEditingController(text: bannerData?['title'] ?? '');
    final descriptionController = TextEditingController(text: bannerData?['description'] ?? '');
    final imageUrlController = TextEditingController(text: bannerData?['imageUrl'] ?? '');
    final actionUrlController = TextEditingController(text: bannerData?['actionUrl'] ?? '');
    String selectedPosition = bannerData?['position'] ?? 'top';
    bool isActive = bannerData?['isActive'] ?? true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_mediumPurple, _darkPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                          isEditing ? Icons.edit : Icons.ad_units,
                          color: _white,
                          size: 24
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Advertisement Banner' : 'Create Advertisement Banner',
                            style: TextStyle(
                              color: _darkPurple,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isEditing ? 'Update banner details' : 'Add a new banner to monetize your app',
                            style: TextStyle(color: _greyText, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _greyText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Title
                        _buildInputField(
                          'Banner Title *',
                          'Enter banner title...',
                          titleController,
                          Icons.title,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        _buildInputField(
                          'Description',
                          'Brief description of the ad...',
                          descriptionController,
                          Icons.description,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Image URL
                        _buildInputField(
                          'Image URL *',
                          'https://example.com/banner.jpg',
                          imageUrlController,
                          Icons.image,
                        ),
                        const SizedBox(height: 16),

                        // Action URL (where banner clicks go)
                        _buildInputField(
                          'Click Action URL *',
                          'https://advertiser-website.com',
                          actionUrlController,
                          Icons.link,
                        ),
                        const SizedBox(height: 20),

                        // Position Selection
                        Text(
                          'Banner Position',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _lightPurple.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<String>(
                            value: selectedPosition,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem(
                                value: 'top',
                                child: Row(
                                  children: [
                                    Icon(Icons.keyboard_arrow_up, color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Top of Homepage'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'middle',
                                child: Row(
                                  children: [
                                    Icon(Icons.drag_handle, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Middle Section'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'bottom',
                                child: Row(
                                  children: [
                                    Icon(Icons.keyboard_arrow_down, color: Colors.green, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Bottom Section'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedPosition = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Status Toggle
                        Row(
                          children: [
                            Text(
                              'Banner Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _darkPurple,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: isActive,
                              onChanged: (value) {
                                setDialogState(() {
                                  isActive = value;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                            Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _greyText.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: _greyText, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_mediumPurple, _darkPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final title = titleController.text.trim();
                              final imageUrl = imageUrlController.text.trim();
                              final actionUrl = actionUrlController.text.trim();

                              if (title.isEmpty || imageUrl.isEmpty || actionUrl.isEmpty) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Please fill all required fields', style: TextStyle(color: _white)),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }

                              final currentUser = FirebaseAuth.instance.currentUser;
                              final now = Timestamp.now();

                              try {
                                final bannerData = {
                                  'title': title,
                                  'description': descriptionController.text.trim(),
                                  'imageUrl': imageUrl,
                                  'actionUrl': actionUrl,
                                  'position': selectedPosition,
                                  'isActive': isActive,
                                  'createdBy': currentUser?.uid,
                                  'updatedAt': now,
                                };

                                if (isEditing) {
                                  // Update existing banner
                                  await FirebaseFirestore.instance
                                      .collection('ad_banners')
                                      .doc(bannerDoc!.id)
                                      .update(bannerData);
                                } else {
                                  // Create new banner
                                  bannerData['createdAt'] = now;
                                  bannerData['clicks'] = 0;
                                  bannerData['impressions'] = 0;

                                  await FirebaseFirestore.instance
                                      .collection('ad_banners')
                                      .add(bannerData);
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          isEditing ? 'Banner updated successfully!' : 'Banner created successfully!',
                                          style: TextStyle(color: _white)
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error ${isEditing ? 'updating' : 'creating'} banner: $e', style: TextStyle(color: _white)),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isEditing ? Icons.save : Icons.add_circle, color: _white),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? 'Update Banner' : 'Create Banner',
                                    style: TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBanner(String bannerId, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Delete Banner', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _greyText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance
            .collection('ad_banners')
            .doc(bannerId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Banner deleted successfully!', style: TextStyle(color: _white)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting banner: $e', style: TextStyle(color: _white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _previewBanner(String actionUrl) async {
    try {
      final uri = Uri.parse(actionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open URL: $actionUrl', style: TextStyle(color: _white)),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid URL: $actionUrl', style: TextStyle(color: _white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkPurple,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _greyText.withValues(alpha: 0.6)),
            prefixIcon: Icon(icon, color: _mediumPurple),
            filled: true,
            fillColor: _lightPurple.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _darkPurple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Banner Management', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.analytics, color: _white),
              tooltip: 'View Analytics',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BannerAnalyticsScreen(),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_mediumPurple, _darkPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: _white),
              tooltip: 'Add New Banner',
              onPressed: () => _showAddBannerDialog(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ad_banners')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _darkPurple));
            }

            final banners = snapshot.data?.docs ?? [];

            if (banners.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ad_units_outlined, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No Advertisement Banners',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkPurple),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first banner to start earning ad revenue',
                      style: TextStyle(fontSize: 16, color: _greyText),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_mediumPurple, _darkPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showAddBannerDialog(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle, color: _white),
                                const SizedBox(width: 8),
                                Text(
                                  'Create First Banner',
                                  style: TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final banner = banners[index];
                final data = banner.data() as Map<String, dynamic>;

                final title = data['title'] ?? 'Untitled Banner';
                final description = data['description'] ?? '';
                final imageUrl = data['imageUrl'] ?? '';
                final actionUrl = data['actionUrl'] ?? '';
                final position = data['position'] ?? 'top';
                final isActive = data['isActive'] ?? false;
                final clicks = data['clicks'] ?? 0;
                final impressions = data['impressions'] ?? 0;
                final createdAt = data['createdAt'] as Timestamp?;

                // Format creation date for display
                final createdDate = createdAt != null
                    ? DateTime.fromMillisecondsSinceEpoch(createdAt.millisecondsSinceEpoch)
                    : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_white, _lightPurple.withValues(alpha: 0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 40,
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _darkPurple,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        description,
                                        style: TextStyle(fontSize: 14, color: _greyText),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (createdDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Created: ${createdDate.day}/${createdDate.month}/${createdDate.year}',
                                        style: TextStyle(fontSize: 12, color: _greyText),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (value) async {
                                  await FirebaseFirestore.instance
                                      .collection('ad_banners')
                                      .doc(banner.id)
                                      .update({'isActive': value});
                                },
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Position and Stats
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPositionColor(position).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getPositionColor(position)),
                                ),
                                child: Text(
                                  position.toUpperCase(),
                                  style: TextStyle(
                                    color: _getPositionColor(position),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '👁 $impressions views • 👆 $clicks clicks',
                                style: TextStyle(fontSize: 12, color: _greyText),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Target: ${Uri.parse(actionUrl).host}',
                            style: TextStyle(fontSize: 12, color: _greyText),
                          ),

                          const SizedBox(height: 12),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _previewBanner(actionUrl),
                                  icon: Icon(Icons.preview, size: 16, color: Colors.blue),
                                  label: Text('Preview', style: TextStyle(color: Colors.blue)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.blue),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showAddBannerDialog(banner),
                                  icon: Icon(Icons.edit, size: 16, color: Colors.orange),
                                  label: Text('Edit', style: TextStyle(color: Colors.orange)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.orange),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _deleteBanner(banner.id, title),
                                  icon: Icon(Icons.delete, size: 16, color: Colors.red),
                                  label: Text('Delete', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              },
            );
          },
        ),
      ),
    );
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'top':
        return Colors.blue;
      case 'middle':
        return Colors.orange;
      case 'bottom':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}