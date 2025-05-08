import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  
  UserModel? _userProfile;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Load user profile
  Future<void> loadUserProfile(String userId) async {
    _setLoading(true);
    _error = null;
    
    try {
      print('ProfileProvider: Loading user profile for $userId');
      final profile = await _profileService.getUserProfile(userId);
      
      if (profile != null) {
        // Проверяем, действительно ли данные изменились, перед уведомлением
        final bool profileChanged = _userProfile == null || 
            _userProfile!.displayName != profile.displayName ||
            _userProfile!.firstName != profile.firstName ||
            _userProfile!.lastName != profile.lastName ||
            _userProfile!.photoURL != profile.photoURL ||
            _userProfile!.bio != profile.bio;
            
        _userProfile = profile;
        
        if (profileChanged) {
          print('ProfileProvider: Profile data changed, notifying listeners');
          notifyListeners(); // Явно вызываем уведомление при изменении данных
        }
        
        print('ProfileProvider: Profile loaded successfully: ${profile.getFullName()}');
      } else {
        print('ProfileProvider: Failed to load profile - profile is null');
      }
      
      _setLoading(false);
    } catch (e) {
      print('ProfileProvider: Error loading profile: $e');
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile({
    required String userId,
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      print('ProfileProvider: Updating user profile for $userId');
      
      final success = await _profileService.updateUserProfile(
        userId: userId,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        bio: bio,
      );
      
      if (success) {
        print('ProfileProvider: Profile updated successfully, reloading profile');
        // Wait a moment for Firestore to update
        await Future.delayed(const Duration(milliseconds: 500));
        // Force reload the profile with fresh data from server
        await _profileService.clearUserProfileCache(userId);
        await loadUserProfile(userId);
        print('ProfileProvider: Profile refreshed after update');
      } else {
        print('ProfileProvider: Failed to update profile');
        _setError('Failed to update profile');
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      print('ProfileProvider: Error updating user profile: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Upload profile image
  Future<bool> uploadProfileImage(String userId, File imageFile) async {
    _setLoading(true);
    _error = null;
    
    try {
      print('ProfileProvider: Starting profile image upload');
      
      // First check if file exists and is readable
      if (!await imageFile.exists()) {
        print('ProfileProvider: File does not exist: ${imageFile.path}');
        _setError('Selected image file does not exist or was deleted');
        _setLoading(false);
        return false;
      }
      
      final fileSize = await imageFile.length();
      print('ProfileProvider: File size: ${fileSize} bytes');
      
      if (fileSize == 0) {
        print('ProfileProvider: File is empty');
        _setError('Selected image file is empty');
        _setLoading(false);
        return false;
      }
      
      final success = await _profileService.uploadProfileImage(userId, imageFile);
      
      if (success) {
        print('ProfileProvider: Upload successful, reloading profile');
        // Wait a moment for Firestore to update
        await Future.delayed(const Duration(milliseconds: 500));
        // Force reload the profile with fresh data from server
        await _profileService.clearUserProfileCache(userId);
        await loadUserProfile(userId);
        print('ProfileProvider: Profile refreshed after image upload');
      } else {
        print('ProfileProvider: Upload failed');
        _setError('Failed to upload profile image. Please check your connection and Firebase storage rules.');
        _setLoading(false);
        return false;
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      print('ProfileProvider: Error uploading profile image: $e');
      _setError('Error uploading image: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      return await _profileService.searchUsers(query);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }
  
  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  // Set error message
  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
  
  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Clear cache and force refresh from server
  Future<void> clearCache() async {
    try {
      if (_userProfile != null) {
        print('ProfileProvider: Clearing profile cache for ${_userProfile!.uid}');
        await _profileService.clearUserProfileCache(_userProfile!.uid);
      }
    } catch (e) {
      print('ProfileProvider: Error clearing cache: $e');
    }
  }
} 