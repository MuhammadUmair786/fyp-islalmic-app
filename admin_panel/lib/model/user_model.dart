import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime joinedDate;
  final bool isBanned;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedDate,
    this.isBanned = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
      role: data['role'] ?? 'User',
      joinedDate: (data['joinedDate'] as Timestamp).toDate(),
      isBanned: data['isBanned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'isBanned': isBanned,
    };
  }
}
