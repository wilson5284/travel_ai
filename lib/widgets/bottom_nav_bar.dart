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

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const HomeScreen(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const ItineraryScreen(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const ChatbotScreen(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const TripTimelineScreen(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
        case 4:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const ProfileScreen(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.15),
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
      child: ClipRRect( // Ensures the BottomNavigationBar itself respects the border radius
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _onItemTapped(context, index),
          backgroundColor: _white, // Explicitly white background for the bar
          type: BottomNavigationBarType.fixed, // Ensures items are evenly spaced

          // Active item color: violet
          selectedItemColor: _mediumPurple,
          // Inactive item color: grey
          unselectedItemColor: _greyText,

          // Keep selected label style same size as unselected
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