import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllAnnouncementsScreen extends StatelessWidget {
  const AllAnnouncementsScreen({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final announcementsRef = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("All Announcements")),
      body: StreamBuilder<QuerySnapshot>(
        stream: announcementsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No announcements yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final message = data['message'] ?? '';
              final date = _formatTimestamp(data['createdAt']);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(message),
                      const SizedBox(height: 8),
                      Text('📅 $date', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
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
