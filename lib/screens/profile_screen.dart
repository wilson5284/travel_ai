import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../model/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  UserModel? _userModel;
  bool _loading = true;
  File? _avatar;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      setState(() {
        _userModel = UserModel.fromMap(doc.data()!);
        _loading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _avatar = File(picked.path);
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(_avatar!);
      final downloadUrl = await ref.getDownloadURL();

      // Update Firestore with avatar URL
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarUrl': downloadUrl,
      });

      // Reload updated user profile
      _loadUserProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar uploaded successfully!')),
      );
    } catch (e) {
      print("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload avatar.')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Delete from Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.delete();

      // Clear avatar URL in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarUrl': FieldValue.delete(),
      });

      setState(() {
        _avatar = null;
        _userModel?.avatarUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removed successfully!')),
      );
    } catch (e) {
      print('Remove avatar error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove avatar.')),
      );
    }
  }


  Future<void> _refreshProfile() async {
    setState(() => _loading = true);
    await _loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _avatar != null
                    ? FileImage(_avatar!)
                    : (_userModel?.avatarUrl != null
                    ? NetworkImage(_userModel!.avatarUrl!)
                    : null) as ImageProvider?,
                child: (_avatar == null && _userModel?.avatarUrl == null)
                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.white70)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (_userModel?.avatarUrl != null)
              TextButton.icon(
                onPressed: _removeAvatar,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  "Remove Avatar",
                  style: TextStyle(color: Colors.red),
                ),
              ),

            Text("Username: ${_userModel?.username ?? '-'}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Email: ${_userModel?.email ?? '-'}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Preferred Language: ${_userModel?.preferredLanguage ?? '-'}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Preferred Currency: ${_userModel?.preferredCurrency ?? '-'}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: _userModel!),
                  ),
                );
                _refreshProfile(); // Reload after edit
              },
              icon: const Icon(Icons.edit),
              label: const Text("Edit Profile"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await _authService.signOut();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}
