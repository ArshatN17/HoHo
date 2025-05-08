import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  user,
  guest
}

class UserModel {
  final String uid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? photoURL;
  final String? bio;
  final List<String> createdEvents;
  final UserRole role;
  final DateTime createdAt;
  final DateTime lastActive;

  UserModel({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.displayName,
    this.photoURL,
    this.bio,
    this.createdEvents = const [],
    this.role = UserRole.user,
    required this.createdAt,
    required this.lastActive,
  });

  // Factory method to create UserModel from Firebase Auth User and additional Firestore data
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Convert role string to enum
    UserRole parseRole(String? roleStr) {
      if (roleStr == 'admin') return UserRole.admin;
      if (roleStr == 'guest') return UserRole.guest;
      return UserRole.user; // Default role
    }
    
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'],
      lastName: map['lastName'],
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      bio: map['bio'],
      createdEvents: List<String>.from(map['createdEvents'] ?? []),
      role: parseRole(map['role']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastActive: (map['lastActive'] as Timestamp).toDate(),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    // Convert enum to string
    String roleToString(UserRole role) {
      return role.toString().split('.').last;
    }
    
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName ?? (firstName != null && lastName != null ? '$firstName $lastName' : null),
      'photoURL': photoURL,
      'bio': bio,
      'createdEvents': createdEvents,
      'role': roleToString(role),
      'createdAt': createdAt,
      'lastActive': lastActive,
    };
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    String? photoURL,
    String? bio,
    List<String>? createdEvents,
    UserRole? role,
    DateTime? lastActive,
  }) {
    return UserModel(
      uid: this.uid,
      email: this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      createdEvents: createdEvents ?? this.createdEvents,
      role: role ?? this.role,
      createdAt: this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  // Generate display name from first and last name
  String getFullName() {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    } else if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return 'User';
    }
  }
  
  // Check if user has admin privileges
  bool get isAdmin => role == UserRole.admin;
  
  // Check if user has at least user privileges (not a guest)
  bool get isUser => role == UserRole.user || role == UserRole.admin;
  
  // Check if user is just a guest
  bool get isGuest => role == UserRole.guest;
} 