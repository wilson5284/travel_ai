import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance.collection('users');

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.orderBy('role').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final username = data['username'] ?? 'Unknown';
              final email = data['email'] ?? 'No email';
              final role = data['role'] ?? 'user';
              final status = data['status'] ?? 'approved';
              final isStopped = status == 'stopped';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(username),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email),
                      Text('Role: $role'),
                      Text('Status: ${isStopped ? 'Stopped ❌' : 'Approved ✅'}'),
                    ],
                  ),
                  trailing: role != 'admin'
                      ? ElevatedButton(
                    onPressed: () {
                      usersRef.doc(doc.id).update({
                        'status': isStopped ? 'approved' : 'stopped',
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isStopped
                              ? 'User re-enabled'
                              : 'User disabled'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isStopped ? Colors.green : Colors.red,
                    ),
                    child: Text(isStopped ? 'Enable' : 'Disable'),
                  )
                      : const Text("Admin"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
