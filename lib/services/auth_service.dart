import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> registerUser(
      String email,
      String password,
      String username,
      String lang,
      String currency, {
        String role = 'user', // 👈 Default role
      }) async {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    User? user = result.user;

    if (user != null) {
      UserModel userModel = UserModel(
        uid: user.uid,
        email: email,
        username: username,
        preferredLanguage: lang,
        preferredCurrency: currency,
        role: role, // 👈 Include role
      );
      await _db.collection("users").doc(user.uid).set(userModel.toMap());
    }
    return user;
  }

  Future<User?> login(String email, String password) async {
    UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
