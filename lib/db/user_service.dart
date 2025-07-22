// lib/db/user_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../model/user_model.dart';

class UserService {
  final fbAuth.FirebaseAuth _auth = fbAuth.FirebaseAuth.instance;
  final CollectionReference _users = FirebaseFirestore.instance.collection('users');

  Future<fbAuth.User?> registerUser(
      String email,
      String password,
      String username,
      String preferredLanguage,
      String preferredCurrency, {
        String role = 'user',
      }) async {
    try {
      fbAuth.UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      fbAuth.User? user = result.user;

      if (user != null) {
        UserModel userModel = UserModel(
          uid: user.uid,
          username: username.trim(),
          email: email.trim(),
          preferredLanguage: preferredLanguage,
          preferredCurrency: preferredCurrency,
          role: role,
        );
        await _users.doc(user.uid).set(userModel.toMap());
      }
      return user;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  Future<void> addUser(UserModel user, String uid, {XFile? image}) async {
    try {
      String? avatarUrl;
      if (image != null) {
        final storageRef = FirebaseStorage.instance.ref().child('avatars/$uid');
        await storageRef.putFile(File(image.path));
        avatarUrl = await storageRef.getDownloadURL();
      }
      final userData = user.toMap();
      if (avatarUrl != null) {
        userData['avatarUrl'] = avatarUrl;
      }
      await _users.doc(uid).set(userData);
    } catch (e) {
      print('Error in addUser: $e');
      rethrow;
    }
  }
  Future<fbAuth.User?> login(String email, String password) async {
    try {
      fbAuth.UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  Future<void> updateUserPhoto(String uid, String photoUrl) async {
    try {
      await _users.doc(uid).update({'avatarUrl': photoUrl});
    } catch (e) {
      print('Error updating user photo: $e');
    }
  }

  Future<void> removeUserAvatar(String uid) async {
    try {
      await _users.doc(uid).update({'avatarUrl': FieldValue.delete()});
    } catch (e) {
      print('Error removing user avatar: $e');
      rethrow;
    }
  }
}