import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'cloudinary_service.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get user profile data
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      print('ProfileService: Getting user profile for $userId');
      // Force a server fetch to get the latest data
      final docSnapshot = await _firestore.collection('users').doc(userId)
          .get(const GetOptions(source: Source.server));
      
      if (docSnapshot.exists) {
        print('ProfileService: User document exists, returning data');
        return UserModel.fromMap({
          ...docSnapshot.data()!,
          'uid': docSnapshot.id,
        });
      } else {
        print('ProfileService: User document does not exist, creating new profile');
        // If document doesn't exist, create it with basic data
        final user = _auth.currentUser;
        if (user != null && user.uid == userId) {
          final now = DateTime.now();
          final userData = UserModel(
            uid: userId,
            email: user.email ?? '',
            displayName: user.displayName,
            photoURL: user.photoURL,
            bio: null,
            createdAt: now,
            lastActive: now,
          );
          
          // Save to Firestore
          await _firestore.collection('users').doc(userId).set(userData.toMap());
          
          print('ProfileService: New user profile created successfully');
          return userData;
        }
      }
      
      print('ProfileService: Could not load or create user profile');
      return null;
    } catch (e) {
      print('ProfileService: Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile data
  Future<bool> updateUserProfile({
    required String userId,
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
    UserRole? role,
    List<String>? createdEvents,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'lastActive': FieldValue.serverTimestamp(),
      };

      if (firstName != null) {
        updateData['firstName'] = firstName;
      }

      if (lastName != null) {
        updateData['lastName'] = lastName;
      }

      if (displayName != null && displayName.isNotEmpty) {
        updateData['displayName'] = displayName;
        // Also update Firebase Auth profile
        if (_auth.currentUser?.uid == userId) {
          await _auth.currentUser?.updateDisplayName(displayName);
        }
      } else if (firstName != null && lastName != null) {
        // If displayName is empty but firstName and lastName are provided,
        // generate a displayName from them
        updateData['displayName'] = '$firstName $lastName';
        // Also update Firebase Auth profile
        if (_auth.currentUser?.uid == userId) {
          await _auth.currentUser?.updateDisplayName('$firstName $lastName');
        }
      }

      if (bio != null) {
        updateData['bio'] = bio;
      }
      
      // Only allow role changes if the current user is an admin
      if (role != null) {
        final currentUserSnap = await _firestore.collection('users').doc(_auth.currentUser?.uid).get();
        if (currentUserSnap.exists) {
          final currentUserData = currentUserSnap.data() as Map<String, dynamic>;
          final currentUserRole = currentUserData['role'] as String?;
          
          if (currentUserRole == 'admin') {
            // Convert enum to string
            updateData['role'] = role.toString().split('.').last;
          }
        }
      }
      
      // Only allow createdEvents changes if the current user is an admin
      if (createdEvents != null) {
        final currentUserSnap = await _firestore.collection('users').doc(_auth.currentUser?.uid).get();
        if (currentUserSnap.exists) {
          final currentUserData = currentUserSnap.data() as Map<String, dynamic>;
          final currentUserRole = currentUserData['role'] as String?;
          
          if (currentUserRole == 'admin') {
            updateData['createdEvents'] = createdEvents;
          }
        }
      }

      await _firestore.collection('users').doc(userId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Upload profile image using Cloudinary and update user profile
  Future<bool> uploadProfileImage(String userId, File imageFile) async {
    try {
      print('ProfileService: Starting profile image upload for user $userId using Cloudinary');
      
      // Upload to Cloudinary
      final imageUrl = await _cloudinaryService.uploadImage(
        imageFile, 
        'profile_images', 
        userId
      );
      
      if (imageUrl == null) {
        print('ProfileService: Failed to upload image to Cloudinary');
        return false;
      }
      
      print('ProfileService: Image uploaded to Cloudinary: $imageUrl');
      
      // Update Firestore with the new image URL
      await _firestore.collection('users').doc(userId).update({
        'photoURL': imageUrl,
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      // Update Auth profile
      if (_auth.currentUser != null && _auth.currentUser!.uid == userId) {
        await _auth.currentUser!.updatePhotoURL(imageUrl);
      }
      
      print('ProfileService: Profile updated with Cloudinary image URL');
      return true;
    } catch (e) {
      print('ProfileService: Error uploading profile image: $e');
      return false;
    }
  }

  // Get user profile by username/display name (for searching users)
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      
      // Search for users with display name containing the query
      final querySnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(10)
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromMap({
                ...doc.data(),
                'uid': doc.id,
              }))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Clear any cached user profile data to ensure fresh data on next load
  Future<void> clearUserProfileCache(String userId) async {
    try {
      print('ProfileService: Clearing cached profile data for $userId');
      // Force a cache refresh by setting the source to Server
      await _firestore.collection('users').doc(userId)
          .get(const GetOptions(source: Source.server));
      print('ProfileService: Profile cache cleared');
    } catch (e) {
      print('ProfileService: Error clearing profile cache: $e');
      // We don't want to throw here, just log the error
    }
  }
} 