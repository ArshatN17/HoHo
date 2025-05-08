import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  bool _isGuestMode = false;
  bool _isAdmin = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _isGuestMode;
  bool get isAdmin => _isAdmin;
  String? get error => _error;

  // Initialize provider and listen to auth state changes
  Future<void> initialize() async {
    _setLoading(true);
    try {
      _authService.authStateChanges.listen((User? user) async {
        _user = user;
        if (user != null) {
          // If a user logs in, exit guest mode
          _isGuestMode = false;
          // Check if the user is admin
          _isAdmin = await _authService.isCurrentUserAdmin();
        } else {
          _isAdmin = false;
        }
        notifyListeners();
      });
      
      // Check if user is logged in from SharedPreferences
      final isLoggedIn = await _authService.isUserLoggedIn();
      if (isLoggedIn && _user == null) {
        // If user is logged in according to SharedPreferences but Firebase Auth says no,
        // it might be a token expiration, so we sign out to reset the state
        await _authService.signOut();
      }
      
      // Check if guest mode was previously enabled
      final isGuestMode = await _authService.isGuestMode();
      _isGuestMode = isGuestMode;
      
      // If user is logged in, check admin status
      if (_user != null) {
        _isAdmin = await _authService.isCurrentUserAdmin();
      }
    } catch (e) {
      print('Error initializing AuthProvider: $e');
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final result = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      _user = result.user;
      
      if (_user != null) {
        await _authService.saveUserSession(_user!.uid);
        // Exit guest mode if user registers
        if (_isGuestMode) {
          await exitGuestMode();
        }
        // Check if the user is admin
        _isAdmin = await _authService.isCurrentUserAdmin();
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final result = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;
      
      if (_user != null) {
        await _authService.saveUserSession(_user!.uid);
        // Exit guest mode if user logs in
        if (_isGuestMode) {
          await exitGuestMode();
        }
        // Check if the user is admin
        _isAdmin = await _authService.isCurrentUserAdmin();
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> logout() async {
    print('AuthProvider: Starting logout process');
    _setLoading(true);
    _error = null;
    
    try {
      print('AuthProvider: Calling _authService.signOut()');
      await _authService.signOut();
      print('AuthProvider: _authService.signOut() completed successfully');
      _user = null;
      _isAdmin = false;
      
      // Exit guest mode too if logging out
      if (_isGuestMode) {
        await exitGuestMode();
      }
      
      _setLoading(false);
      print('AuthProvider: Logout process completed');
    } catch (e) {
      print('AuthProvider: Error in logout: $e');
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Enter guest mode
  Future<bool> enterGuestMode() async {
    _setLoading(true);
    _error = null;
    
    try {
      // Save guest mode preference
      await _authService.saveGuestMode(true);
      _isGuestMode = true;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Exit guest mode
  Future<bool> exitGuestMode() async {
    try {
      await _authService.saveGuestMode(false);
      _isGuestMode = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error exiting guest mode: $e');
      return false;
    }
  }
  
  // Set admin privileges for a user
  Future<bool> setUserAsAdmin(String userId) async {
    try {
      if (!_isAdmin) {
        _setError('Only admins can perform this action');
        return false;
      }
      
      final result = await _authService.setUserAsAdmin(userId);
      if (!result) {
        _setError('Failed to set user as admin');
      }
      return result;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Remove admin privileges from a user
  Future<bool> removeAdminRole(String userId) async {
    try {
      if (!_isAdmin) {
        _setError('Only admins can perform this action');
        return false;
      }
      
      final result = await _authService.removeAdminRole(userId);
      if (!result) {
        _setError('Failed to remove admin role');
      }
      return result;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Get current user role
  Future<UserRole> getCurrentUserRole() async {
    if (_user == null) {
      return UserRole.guest;
    }
    return _authService.getCurrentUserRole();
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
} 