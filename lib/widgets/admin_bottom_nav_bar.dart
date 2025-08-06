// lib/widgets/admin_bottom_nav_bar.dart
import 'package:flutter/material.dart';

class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;

  // Consistent Color Scheme
  final Color _darkPurple = const Color(0xFF6A1B9A);
  //final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _white = Colors.white;

  const AdminBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
        break;
      case 1:
        Navigator.pushNamed(context, '/admin/reports');
        break;
      case 2:
        Navigator.pushNamed(context, '/admin/users');
        break;
      case 3:
        Navigator.pushNamed(context, '/admin/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: _white,
        selectedItemColor: _darkPurple,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentIndex == 0 ? _lightPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dashboard,
                color: currentIndex == 0 ? _darkPurple : Colors.grey.shade600,
              ),
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentIndex == 1 ? _lightPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.report,
                color: currentIndex == 1 ? _darkPurple : Colors.grey.shade600,
              ),
            ),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentIndex == 2 ? _lightPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.people,
                color: currentIndex == 2 ? _darkPurple : Colors.grey.shade600,
              ),
            ),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentIndex == 3 ? _lightPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: currentIndex == 3 ? _darkPurple : Colors.grey.shade600,
              ),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}