// lib/model/user_model.dart
class UserModel {
  final String? uid;
  final String username;
  final String email;
  final String? preferredLanguage;
  final String? preferredCurrency;
  final String? country;
  final String? phone;
  final String? gender;
  final String? dob;
  final String? createdAt;
  final String? role;
  final String? avatarUrl;

  UserModel({
    this.uid,
    required this.username,
    required this.email,
    this.preferredLanguage,
    this.preferredCurrency,
    this.country,
    this.phone,
    this.gender,
    this.dob,
    this.createdAt,
    this.role,
    this.avatarUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'preferredLanguage': preferredLanguage,
      'preferredCurrency': preferredCurrency,
      'country': country,
      'phone': phone,
      'gender': gender,
      'dob': dob,
      'createdAt': createdAt,
      'role': role,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String?,
      username: map['username'] as String,
      email: map['email'] as String,
      preferredLanguage: map['preferredLanguage'] as String?,
      preferredCurrency: map['preferredCurrency'] as String?,
      country: map['country'] as String?,
      phone: map['phone'] as String?,
      gender: map['gender'] as String?,
      dob: map['dob'] as String?,
      createdAt: map['createdAt'] as String?,
      role: map['role'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
    );
  }
}