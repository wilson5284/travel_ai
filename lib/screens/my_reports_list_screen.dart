import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import the ReportThreadScreen for re-use
import '../admin/report_management_screen.dart';

class MyReportsListScreen extends StatelessWidget {
  const MyReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reports')),
        body: const Center(child: Text('Please log in to view your reports.')),
      );
    }

    final reportsRef = FirebaseFirestore.instance.collection('reports');

    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: reportsRef
            .where('userId', isEqualTo: user.uid)
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('You have not submitted any reports yet.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final initialReport = data['report'] ?? 'No message provided';
              final status = data['status'] ?? 'pending';
              final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(initialReport.length > 50 ? '${initialReport.substring(0, 50)}...' : initialReport),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${status.toUpperCase()}'),
                      if (lastUpdated != null)
                        Text('Last Update: ${lastUpdated.toLocal().toString().split('.')[0]}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserReportThreadScreen(reportId: doc.id), // Use a specific User report thread screen
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Re-using the logic from Admin's ReportThreadScreen but with user sender
class UserReportThreadScreen extends StatefulWidget {
  final String reportId;

  const UserReportThreadScreen({super.key, required this.reportId});

  @override
  State<UserReportThreadScreen> createState() => _UserReportThreadScreenState();
}

class _UserReportThreadScreenState extends State<UserReportThreadScreen> {
  final TextEditingController _replyController = TextEditingController();
  late DocumentReference _reportRef;

  @override
  void initState() {
    super.initState();
    _reportRef = FirebaseFirestore.instance.collection('reports').doc(widget.reportId);
  }

  Future<void> _sendReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to reply.')),
      );
      return;
    }

    final timestamp = Timestamp.now();

    await _reportRef.update({
      'messages': FieldValue.arrayUnion([
        {
          'sender': 'user', // User is sending the reply
          'message': reply,
          'timestamp': timestamp,
        }
      ]),
      'lastUpdated': timestamp,
      'status': 'open', // User replies keep it open for admin to see
    });

    _replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Report Thread")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _reportRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final messages = (data['messages'] as List<dynamic>? ?? [])
              .map((m) => m as Map<String, dynamic>)
              .toList();

          messages.sort((a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp']));

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final sender = msg['sender'];
                    final message = msg['message'];
                    final time = (msg['timestamp'] as Timestamp).toDate();

                    final isUser = sender == 'user'; // Check if the sender is the user

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.green[100] : Colors.blue[100], // Different colors for user/admin
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUser ? "You" : "Admin",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(message),
                            Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: const InputDecoration(
                          hintText: 'Type your reply...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendReply,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}