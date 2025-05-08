import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email, 
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _createUserDocument(
        result.user!,
        firstName: firstName,
        lastName: lastName,
      );
      
      return result;
    } catch (e) {
      print('Error registering: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last active timestamp
      await _updateUserLastActive(result.user!.uid);
      
      return result;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('AuthService: Starting signOut process');
      // Update last active timestamp before sign out
      if (currentUser != null) {
        print('AuthService: Updating last active timestamp for user ${currentUser!.uid}');
        try {
          await _updateUserLastActive(currentUser!.uid);
          print('AuthService: Last active timestamp updated successfully');
        } catch (e) {
          print('AuthService: Error updating last active timestamp: $e');
          // Continue with logout even if updating last active fails
        }
      } else {
        print('AuthService: No current user to update last active timestamp');
      }
      
      // Clear session data
      print('AuthService: Getting SharedPreferences instance');
      final prefs = await SharedPreferences.getInstance();
      print('AuthService: Removing user_uid from SharedPreferences');
      await prefs.remove('user_uid');
      print('AuthService: SharedPreferences cleared');
      
      print('AuthService: Calling Firebase Auth signOut');
      await _auth.signOut();
      print('AuthService: Firebase Auth signOut completed');
      
      return;
    } catch (e) {
      print('AuthService: Error signing out: $e');
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(
    User user, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      print('AuthService: Creating user document for ${user.uid}');
      final userDoc = _firestore.collection('users').doc(user.uid);
      final now = DateTime.now();
      
      // Check if the document already exists
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        print('AuthService: User document does not exist, creating new one');
        
        // Generate displayName from first and last name
        String? displayName;
        if (firstName != null && lastName != null) {
          displayName = '$firstName $lastName';
        } else if (firstName != null) {
          displayName = firstName;
        } else if (lastName != null) {
          displayName = lastName;
        }
        
        // Update Firebase Auth profile with display name
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        
        // Create new user document
        final userData = UserModel(
          uid: user.uid,
          email: user.email!,
          firstName: firstName,
          lastName: lastName,
          displayName: displayName ?? user.displayName,
          photoURL: user.photoURL,
          bio: null,
          createdAt: now,
          lastActive: now,
        ).toMap();
        
        await userDoc.set(userData);
        print('AuthService: User document created successfully');
      } else {
        print('AuthService: User document already exists, updating lastActive');
        // Just update the lastActive field
        await userDoc.update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('AuthService: Error creating user document: $e');
      // Don't throw the error, just log it
    }
  }

  // Update user's last active timestamp
  Future<void> _updateUserLastActive(String uid) async {
    try {
      print('AuthService: Updating last active timestamp in Firestore for user $uid');
      // First check if the document exists
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (docSnapshot.exists) {
        await _firestore.collection('users').doc(uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
        print('AuthService: Last active timestamp updated in Firestore');
      } else {
        print('AuthService: User document not found in Firestore, cannot update last active');
      }
    } catch (e) {
      print('AuthService: Error updating last active timestamp in Firestore: $e');
      // Don't rethrow the error, so it doesn't block logout
    }
  }

  // Save user session to SharedPreferences
  Future<void> saveUserSession(String uid) async {
    try {
      print('AuthService: Saving user session for $uid');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', uid);
      print('AuthService: Successfully saved user session');
    } catch (e) {
      print('AuthService: Error saving user session: $e');
      // Don't rethrow to prevent login/registration failures
    }
  }

  // Check if user is logged in from SharedPreferences
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid');
    return uid != null && uid.isNotEmpty;
  }

  // Save guest mode preference to SharedPreferences
  Future<void> saveGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guest_mode', isGuest);
  }

  // Check if guest mode is enabled from SharedPreferences
  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('guest_mode') ?? false;
  }

  // Clear guest mode when signing out
  Future<void> clearGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_mode');
  }
  
  // Get the current user's role
  Future<UserRole> getCurrentUserRole() async {
    try {
      if (currentUser == null) {
        return UserRole.guest;
      }
      
      final docSnapshot = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!docSnapshot.exists) {
        return UserRole.user;
      }
      
      final userData = docSnapshot.data();
      String roleStr = userData?['role'] ?? 'user';
      
      if (roleStr == 'admin') {
        return UserRole.admin;
      } else if (roleStr == 'guest') {
        return UserRole.guest;
      } else {
        return UserRole.user;
      }
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.user;
    }
  }
  
  // Check if the current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role == UserRole.admin;
  }
  
  // Set admin role for a user
  Future<bool> setUserAsAdmin(String userId) async {
    try {
      // Check if the current user is an admin first
      if (!(await isCurrentUserAdmin())) {
        print('Only admins can set other users as admins');
        return false;
      }
      
      await _firestore.collection('users').doc(userId).update({
        'role': 'admin',
      });
      
      print('User set as admin successfully');
      return true;
    } catch (e) {
      print('Error setting user as admin: $e');
      return false;
    }
  }
  
  // Remove admin role from a user
  Future<bool> removeAdminRole(String userId) async {
    try {
      // Check if the current user is an admin first
      if (!(await isCurrentUserAdmin())) {
        print('Only admins can remove admin roles');
        return false;
      }
      
      await _firestore.collection('users').doc(userId).update({
        'role': 'user',
      });
      
      print('Admin role removed successfully');
      return true;
    } catch (e) {
      print('Error removing admin role: $e');
      return false;
    }
  }
} 