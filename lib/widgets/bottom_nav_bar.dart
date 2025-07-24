import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot_screen.dart';
<<<<<<< HEAD
import '../screens/dynamic_itinerary/itinerary_screen.dart';
import '../screens/user_management/profile_screen.dart';
=======
import '../screens/profile_screen.dart';
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

<<<<<<< HEAD
  // Consistent Color Scheme - now all are truly const
  static const Color _white = Colors.white;
  static const Color _mediumPurple = Color(0xFF9C27B0);
  static const Color _greyText = Color(0xFF757575);

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
=======
  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Prevent redundant navigation

>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
<<<<<<< HEAD
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const HomeScreen(),
            transitionDuration: Duration.zero,
          ),
=======
          MaterialPageRoute(builder: (_) => const HomeScreen()),
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
<<<<<<< HEAD
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const ItineraryScreen(),
            transitionDuration: Duration.zero,
          ),
=======
          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
<<<<<<< HEAD
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
=======
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Container(
      decoration: const BoxDecoration( // Changed to const
        color: _white, // Set container background to white
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000), // Hex for Colors.grey.withOpacity(0.15)
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, -4), // Subtle shadow pointing upwards
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20), // Slight curve to the top
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect( // Ensures the BottomNavigationBar itself respects the border radius
        borderRadius: const BorderRadius.only( // Changed to const
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
            color: _mediumPurple,
          ),
          unselectedLabelStyle: const TextStyle(
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
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
=======
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      onTap: (index) => _onItemTapped(context, index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chatbot'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
>>>>>>> ef10df6a17e9d6579d4bfd5fc074ac3abd72650f
