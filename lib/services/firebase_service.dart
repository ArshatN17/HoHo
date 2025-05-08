import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Getters
  static FirebaseAuth get auth => _auth;
  static FirebaseFirestore get firestore => _firestore;
  static FirebaseStorage get storage => _storage;

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
      
      // Make sure Firebase Security Rules are compatible with our app
      print('Firebase Storage initialized with default security rules');
      print('If storage uploads fail, please check Firebase Console to set proper Storage Rules:');
      print('rules_version = \'2\';');
      print('service firebase.storage {');
      print('  match /b/{bucket}/o {');
      print('    match /{allPaths=**} {');
      print('      allow read, write: if request.auth != null;');
      print('    }');
      print('  }');
      print('}');
      
    } catch (e) {
      print('Failed to initialize Firebase: $e');
      rethrow;
    }
  }

  // Firestore Rules (for documentation purpose only)
  static String get firestoreRules => '''
    // Firestore rules
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        // Allow anyone to read public data
        match /{document=**} {
          allow read: if true;
        }
        
        // Only authenticated users can write to their own data
        match /users/{userId} {
          allow write: if request.auth != null && request.auth.uid == userId;
        }
        
        // Posts can be created by authenticated users
        match /posts/{postId} {
          allow create: if request.auth != null;
          allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
        }
      }
    }
  ''';
  
  // Storage Rules (for documentation purpose only)
  static String get storageRules => '''
    // Storage rules
    rules_version = '2';
    service firebase.storage {
      match /b/{bucket}/o {
        // Allow users to read all profile images
        match /profile_images/{allImages=**} {
          allow read: if true;
        }
        
        // Allow users to upload their own profile image
        match /profile_images/{userId}.jpg {
          allow write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
  ''';
} 