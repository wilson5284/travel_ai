// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'screen/home/home_screen.dart'; // Import your HomeScreen
import 'firebase_options.dart'; // Make sure this file exists after Firebase setup

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (as you already have)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Firebase initialized.');

  // Note: For google_generative_ai package, you don't call Gemini.init().
  // You directly create an instance of GenerativeModel as you've done in GeminiService.
  // The Gemini.init() method is part of the 'flutter_gemini' package, not 'google_generative_ai'.
  // Since you're using 'google_generative_ai', your GeminiService is set up correctly.

  runApp(
    DevicePreview(
      enabled: true, // Set to false for release builds
      builder: (context) => const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // For DevicePreview
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // Your actual home screen will be HomeScreen
      home: const HomeScreen(), // <--- This is the key change here
      // You can define routes here if you have more screens
      // routes: {
      //   '/history': (context) => const HistoryScreen(),
      // },
    );
  }
}