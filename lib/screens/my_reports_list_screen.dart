// lib/screens/home/my_reports_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import the ReportManagementScreen correctly
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

          if (snapshot.hasError) {
            print('Firebase Stream Error (MyReportsListScreen): ${snapshot.error}');
            return Center(child: Text('Error loading reports: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('You have not submitted any reports yet.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final reportDoc = docs[index];
              final data = reportDoc.data() as Map<String, dynamic>;
              final reportId = reportDoc.id; // Get the document ID for navigation

              final String reportText = data['report'] ?? 'No report text available';
              final String status = data['status'] ?? 'Unknown';
              final Timestamp createdAt = data['createdAt'] ?? Timestamp.now(); // Default if null

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    reportText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      'Status: $status | Submitted: ${createdAt.toDate().toLocal().toString().split(' ')[0]}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to the detail screen for this specific report
                    // Use the correct class name: ReportManagementScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportManagementScreen(reportId: reportId),
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