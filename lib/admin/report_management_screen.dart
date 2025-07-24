import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// The ReportManagementScreen is now a StatefulWidget to manage its internal state,
// specifically whether the current user viewing the report is an admin.
class ReportManagementScreen extends StatefulWidget {
  final String reportId; // reportId is required to fetch the specific report

  const ReportManagementScreen({super.key, required this.reportId});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  final TextEditingController _replyController = TextEditingController();
  String? _currentUserUid;
  bool _isAdmin = false;
  bool _isLoadingRole = true; // To manage the loading state of the user's role

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    _checkUserRole(); // Check the user's role when the screen initializes
  }

  // Fetches the current user's role from the 'users' collection in Firestore.
  Future<void> _checkUserRole() async {
    if (_currentUserUid == null) {
      setState(() {
        _isLoadingRole = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
      if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
        setState(() {
          _isAdmin = true;
        });
      }
    } catch (e) {
      print('Error checking user role: $e'); // Print error if role check fails
    } finally {
      setState(() {
        _isLoadingRole = false; // Set loading to false once check is complete
      });
    }
  }

  // Sends a reply message to the report.
  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return; // Prevent sending empty messages

    final String messageText = _replyController.text.trim();
    _replyController.clear(); // Clear the input field immediately after sending

    try {
      await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
        'messages': FieldValue.arrayUnion([
          {
            'sender': _isAdmin ? 'admin' : 'user', // Sender is 'admin' if current user is admin, else 'user'
            'message': messageText,
            'timestamp': Timestamp.now(),
          }
        ]),
        'lastUpdated': Timestamp.now(), // Update 'lastUpdated' to sort reports correctly
      });
    } catch (e) {
      print('Error sending reply: $e'); // Log error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reply: ${e.toString()}')), // Show error to user
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while fetching user role
    if (_isLoadingRole) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Report...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')), // Consistent app bar title
      body: StreamBuilder<DocumentSnapshot>( // Stream the single report document
        stream: FirebaseFirestore.instance.collection('reports').doc(widget.reportId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Firebase Report Detail Stream Error: ${snapshot.error}'); // Log stream errors
            return Center(child: Text('Error loading report: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Report not found.')); // Handle case where report doesn't exist
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> messages = data['messages'] ?? [];
          final String status = data['status'] ?? 'pending';
          final String userEmail = data['email'] ?? 'Unknown User'; // Display the original reporter's email

          return Column(
            children: [
              // Section to display report status and original reporter's email
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Status: ${status.toUpperCase()}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Report by: $userEmail',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    // Admin-only controls for changing report status
                    if (_isAdmin) ...[ // Use spread operator to conditionally add widgets
                      const SizedBox(height: 10),
                      DropdownButton<String>(
                        value: status,
                        items: <String>['pending', 'in-progress', 'resolved', 'closed']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (String? newValue) async {
                          if (newValue != null && newValue != status) {
                            try {
                              await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
                                'status': newValue,
                                'lastUpdated': Timestamp.now(),
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Status updated to $newValue')),
                              );
                            } catch (e) {
                              print('Error updating status: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update status: ${e.toString()}')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              // Expanded view for chat messages
              Expanded(
                child: ListView.builder(
                  reverse: false, // Display messages in chronological order (oldest first)
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index] as Map<String, dynamic>;
                    final String sender = messageData['sender'] ?? 'unknown';
                    final String message = messageData['message'] ?? '';
                    final Timestamp timestamp = messageData['timestamp'] ?? Timestamp.now();
                    final DateTime time = timestamp.toDate();

                    bool isCurrentUserMessage = false;
                    // Check if the message is from the user who owns this report
                    if (sender == 'user' && _currentUserUid == data['userId']) {
                      isCurrentUserMessage = true;
                    }
                    // Check if the message is from an admin AND the current user IS an admin
                    else if (sender == 'admin' && _isAdmin) {
                      isCurrentUserMessage = true;
                    }

                    return Align(
                      alignment: isCurrentUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrentUserMessage ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCurrentUserMessage ? "You" : (sender == 'admin' ? "Admin" : "User"),
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
              // Message input field for replies
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