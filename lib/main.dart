import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:travel_ai/screens/all_announcements_screen.dart';
import 'package:travel_ai/screens/my_reports_list_screen.dart';
import 'package:travel_ai/screens/splash_screen.dart';
import 'package:travel_ai/screens/user_management/faq_screen.dart';
import 'admin/admin_announcement_list_screen.dart';
import 'admin/user_management_screen.dart';
import 'screens/user_management/login_screen.dart';
import 'screens/report_screen.dart';
import 'screens/trip_timeline_screen.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Optional: Add consistent theme styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/report': (context) => const ReportScreen(),
        '/admin/users': (context) => const UserManagementScreen(),
        '/announcements': (context) => const AllAnnouncementsScreen(),
        '/admin/announcements/manage': (context) => const AdminAnnouncementListScreen(),
        '/report/list': (context) => const MyReportsListScreen(),
        '/faq': (context) => const FAQScreen(),
      },
    );
  }
}
