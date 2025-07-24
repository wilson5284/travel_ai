import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportManagementScreen extends StatelessWidget {
  const ReportManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportsRef = FirebaseFirestore.instance.collection('reports');

    return Scaffold(
      appBar: AppBar(title: const Text('User Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: reportsRef.orderBy('lastUpdated', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final email = data['email'] ?? 'unknown';
              final status = data['status'] ?? 'open';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(email),
                  subtitle: Text('Status: $status'),
                  trailing: const Icon(Icons.message),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportThreadScreen(reportId: doc.id),
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

class ReportThreadScreen extends StatefulWidget {
  final String reportId;

  const ReportThreadScreen({super.key, required this.reportId});

  @override
  State<ReportThreadScreen> createState() => _ReportThreadScreenState();
}

class _ReportThreadScreenState extends State<ReportThreadScreen> {
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

    final timestamp = Timestamp.now();

    await _reportRef.update({
      'messages': FieldValue.arrayUnion([
        {
          'sender': 'admin',
          'message': reply,
          'timestamp': timestamp,
        }
      ]),
      'lastUpdated': timestamp,
      'status': 'open', // remain open until manually closed
    });

    _replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Thread")),
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

                    final isAdmin = sender == 'admin';

                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.blue[100] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin ? "Admin" : "User",
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