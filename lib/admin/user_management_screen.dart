// lib/screens/admin/user_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/admin_bottom_nav_bar.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  String _filterRole = 'all';

  // Consistent Color Scheme
  final Color _white = Colors.white;
  final Color _offWhite = const Color(0xFFF5F5F5);
  final Color _darkPurple = const Color(0xFF6A1B9A);
  final Color _mediumPurple = const Color(0xFF9C27B0);
  final Color _lightPurple = const Color(0xFFF3E5F5);
  final Color _greyText = Colors.grey.shade600;
  final Color _gradientStart = const Color(0xFFF3E5F5);
  final Color _gradientEnd = const Color(0xFFFFF5E6);

  Widget _buildUserAvatar(String? avatarUrl, String username) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_mediumPurple, _darkPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: 25,
        backgroundColor: _lightPurple,
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: TextStyle(color: _mediumPurple, fontWeight: FontWeight.bold, fontSize: 20),
        )
            : null,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isApproved = status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApproved ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        isApproved ? 'Active' : 'Stopped',
        style: TextStyle(
          color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final bool isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? _darkPurple.withOpacity(0.1) : _mediumPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAdmin ? _darkPurple : _mediumPurple,
          width: 1,
        ),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(
          color: isAdmin ? _darkPurple : _mediumPurple,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> usersQuery = FirebaseFirestore.instance
        .collection('users')
        .orderBy('role');

    if (_filterRole != 'all') {
      usersQuery = usersQuery.where('role', isEqualTo: _filterRole);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Manage Users', style: TextStyle(color: _darkPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _white,
        foregroundColor: _darkPurple,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              Container(
                color: Colors.grey.shade200,
                height: 1.0,
              ),
              Container(
                color: _white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        hintStyle: TextStyle(color: _greyText),
                        prefixIcon: Icon(Icons.search, color: _darkPurple),
                        filled: true,
                        fillColor: _lightPurple.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Admins', 'admin'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Users', 'user'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: usersQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _darkPurple));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No users found.',
                      style: TextStyle(fontSize: 18, color: _greyText),
                    ),
                  ],
                ),
              );
            }

            // Filter by search query
            final filteredDocs = _searchQuery.isEmpty
                ? docs
                : docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final username = (data['username'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return username.contains(_searchQuery) || email.contains(_searchQuery);
            }).toList();

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: _lightPurple),
                    const SizedBox(height: 16),
                    Text(
                      'No users match your search.',
                      style: TextStyle(fontSize: 18, color: _greyText),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final username = data['username'] ?? 'Unknown';
                final email = data['email'] ?? 'No email';
                final role = data['role'] ?? 'user';
                final status = data['status'] ?? 'approved';
                final avatarUrl = data['avatarUrl'];
                final isStopped = status == 'stopped';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  shadowColor: _mediumPurple.withOpacity(0.1),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_white, _lightPurple.withOpacity(0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildUserAvatar(avatarUrl, username),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _darkPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(fontSize: 14, color: _greyText),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildRoleChip(role),
                                    const SizedBox(width: 8),
                                    _buildStatusChip(status),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (role != 'admin')
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isStopped
                                      ? [Colors.green.shade400, Colors.green.shade600]
                                      : [Colors.red.shade400, Colors.red.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isStopped ? Colors.green : Colors.red).withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(doc.id)
                                        .update({
                                      'status': isStopped ? 'approved' : 'stopped',
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isStopped ? 'User re-enabled' : 'User disabled',
                                          style: TextStyle(color: _white),
                                        ),
                                        backgroundColor: isStopped ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text(
                                      isStopped ? 'Enable' : 'Disable',
                                      style: TextStyle(
                                        color: _white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _filterRole == value;
    return GestureDetector(
      onTap: () => setState(() => _filterRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [_mediumPurple, _darkPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : _lightPurple.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _darkPurple : _mediumPurple.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _white : _darkPurple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}