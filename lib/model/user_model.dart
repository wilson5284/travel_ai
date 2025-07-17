// lib/model/user_model.dart
class UserModel {
  String? uid;
  String? username;
  String? email;
  String? preferredLanguage;
  String? preferredCurrency;
  String? country;
  String? phone;
  String? gender;
  String? dob;
  String? createdAt;
  String? role;

  UserModel({
    this.uid,
    this.username,
    this.email,
    this.preferredLanguage,
    this.preferredCurrency,
    this.country,
    this.phone,
    this.gender,
    this.dob,
    this.createdAt,
    this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      username: map['username'],
      email: map['email'],
      preferredLanguage: map['preferredLanguage'],
      preferredCurrency: map['preferredCurrency'],
      country: map['country'],
      phone: map['phone'],
      gender: map['gender'],
      dob: map['dob'],
      createdAt: map['createdAt'],
      role: map['role'],
    );
  }

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
    };
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? preferredLanguage,
    String? preferredCurrency,
    String? country,
    String? phone,
    String? gender,
    String? dob,
    String? createdAt,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
    );
  }
}