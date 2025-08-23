import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/dynamic_itinerary/itinerary_screen.dart';
import '../screens/trip_timeline_screen.dart';
import '../screens/user_management/profile_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _mediumPurple = const Color(0xFF9C27B0);
  static const Color _greyText = Color(0xFF757575);

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    // Clear the navigation stack and push the new route
    Widget targetScreen;

    switch (index) {
      case 0:
        targetScreen = const HomeScreen();
        break;
      case 1:
        targetScreen = const ItineraryScreen();
        break;
      case 2:
        targetScreen = const ChatbotScreen();
        break;
      case 3:
        targetScreen = const TripTimelineScreen();
        break;
      case 4:
        targetScreen = const ProfileScreen();
        break;
      default:
        return;
    }

    // Use pushAndRemoveUntil to ensure clean navigation
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => targetScreen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
          (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _onItemTapped(context, index),
          backgroundColor: _white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _mediumPurple,
          unselectedItemColor: _greyText,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
            color: _mediumPurple,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
            color: _greyText,
          ),
          iconSize: 24.0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.travel_explore),
              label: 'Itinerary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble),
              label: 'Chatbot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}