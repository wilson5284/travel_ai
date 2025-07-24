import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/dynamic_itinerary/itinerary_screen.dart';
import '../screens/user_management/profile_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _mediumPurple = const Color(0xFF9C27B0); // Your violet color
  static const Color _greyText = Color(0xFF757575); // Unselected color

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Prevent redundant navigation

    // Use PageRouteBuilder with Duration.zero for no transition
    // This is efficient and suitable for bottom navigation.
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
        color: _white, // Set container background to white
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -4), // Subtle shadow pointing upwards
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20), // Slight curve to the top
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
            fontWeight: FontWeight.normal, // Keep normal weight
            fontSize: 11, // Keep original font size
            color: _mediumPurple, // Violet color
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal, // Keep normal weight
            fontSize: 11, // Keep original font size
            color: _greyText, // Grey color
          ),
          // Set icon size for both selected and unselected
          iconSize: 24.0, // Standard icon size, adjust if your current icons are different

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home), // Only one icon style
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.travel_explore), // Only one icon style, changed to travel_explore
              label: 'Itinerary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble), // Only one icon style
              label: 'Chatbot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person), // Only one icon style
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}