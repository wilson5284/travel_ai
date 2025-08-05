import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/dynamic_itinerary/itinerary_screen.dart';
import '../screens/user_management/profile_screen.dart';
import '../screens/trip_timeline_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

  // Consistent Color Scheme
  static const Color _white = Colors.white;
  static const Color _mediumPurple = Color(0xFF9C27B0);
  static const Color _greyText = Color(0xFF757575);

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget destination;
    switch (index) {
      case 0:
        destination = const HomeScreen();
        break;
      case 1:
        destination = const ItineraryScreen();
        break;
      case 2:
        destination = const ChatbotScreen();
        break;
      case 3:
        destination = const TripTimelineScreen();
        break;
      case 4:
        destination = const ProfileScreen();
        break;
      default:
        return; // Invalid index, do nothing
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => destination,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
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
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
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