import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:travel_ai/screens/all_announcements_screen.dart';
import 'package:travel_ai/screens/my_reports_list_screen.dart';

import 'admin/admin_announcement_list_screen.dart';
import 'admin/report_management_screen.dart';
import 'admin/user_management_screen.dart';
import 'screens/login_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Travel AI',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login', // Change initialRoute to '/login'
      routes: {
        '/login': (context) => const LoginScreen(),
        '/report': (context) => const ReportScreen(),
        '/admin/reports': (context) => const ReportManagementScreen(),
        '/admin/users': (context) => const UserManagementScreen(),
        '/announcements': (context) => const AllAnnouncementsScreen(),
        '/admin/announcements/manage': (context) => const AdminAnnouncementListScreen(),
        '/report/list': (context) => const MyReportsListScreen(),
      },
    );
  }
}