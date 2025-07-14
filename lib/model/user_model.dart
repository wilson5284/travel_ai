class UserModel {
  String? uid;
  String? email;
  String? username;
  String? preferredLanguage;
  String? preferredCurrency;
  String? avatarUrl; // ✅ NEW

  UserModel({
    this.uid,
    this.email,
    this.username,
    this.preferredLanguage,
    this.preferredCurrency,
    this.avatarUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      username: map['username'],
      preferredLanguage: map['preferredLanguage'],
      preferredCurrency: map['preferredCurrency'],
      avatarUrl: map['avatarUrl'], // ✅ NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'preferredLanguage': preferredLanguage,
      'preferredCurrency': preferredCurrency,
      'avatarUrl': avatarUrl, // ✅ NEW
    };
  }
}
