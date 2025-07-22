import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAnnouncementListScreen extends StatefulWidget {
  const AdminAnnouncementListScreen({super.key});

  @override
  State<AdminAnnouncementListScreen> createState() =>
      _AdminAnnouncementListScreenState();
}

class _AdminAnnouncementListScreenState
    extends State<AdminAnnouncementListScreen> {
  bool _isDescending = true;

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Announcement'),
        content:
        const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(id)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement deleted.')),
      );
    }
  }

  Future<void> _showEditDialog({
    String? id,
    String? initialTitle,
    String? initialMessage,
  }) async {
    final titleController = TextEditingController(text: initialTitle ?? '');
    final messageController = TextEditingController(text: initialMessage ?? '');
    final isNew = id == null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isNew ? 'Create Announcement' : 'Edit Announcement'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: Text(isNew ? 'Post' : 'Update'),
            onPressed: () async {
              final title = titleController.text.trim();
              final message = messageController.text.trim();
              final now = Timestamp.now();

              if (title.isEmpty || message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and message required.')),
                );
                return;
              }

              final ref = FirebaseFirestore.instance.collection('announcements');

              if (isNew) {
                await ref.add({
                  'title': title,
                  'message': message,
                  'createdAt': now,
                  'latestActivity': now,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement posted!')),
                );
              } else {
                await ref.doc(id).update({
                  'title': title,
                  'message': message,
                  'editedAt': now,
                  'latestActivity': now,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement updated!')),
                );
              }

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcementsRef = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('latestActivity', descending: _isDescending);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Announcements"),
        actions: [
          IconButton(
            icon: Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: 'Toggle Order',
            onPressed: () => setState(() => _isDescending = !_isDescending),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Announcement',
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: announcementsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No announcements found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final id = doc.id;
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? '';
              final message = data['message'] ?? '';
              final hasEdited = data['editedAt'] != null;
              final timeLabel = hasEdited ? '🛠️ Edited' : '🕒 Created';
              final timestamp = data['latestActivity'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: ListTile(
                  onTap: () => _showEditDialog(
                    id: id,
                    initialTitle: title,
                    initialMessage: message,
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(message),
                      const SizedBox(height: 6),
                      Text(
                        '$timeLabel: ${_formatDateTime(timestamp)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteAnnouncement(id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
