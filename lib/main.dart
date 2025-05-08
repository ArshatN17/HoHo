import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:social_app/providers/profile_provider.dart';
import 'package:social_app/providers/event_provider.dart';
import 'package:social_app/screens/auth_screen.dart';
import 'package:social_app/screens/home_screen.dart';
import 'package:social_app/screens/splash_screen.dart';
import 'package:social_app/screens/guest_screen.dart';
import 'package:social_app/services/firebase_service.dart';
import 'package:social_app/services/notification_service.dart';
import 'package:social_app/providers/auth_provider.dart';
import 'package:social_app/services/event_service.dart';
import 'package:social_app/providers/comment_provider.dart';
import 'package:social_app/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: const SplashScreen(),
            theme: AppTheme.lightTheme,
          );
        }
        
        if (snapshot.hasError) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: Text('Error initializing app: ${snapshot.error}'),
              ),
            ),
          );
        }
        
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => EventProvider()),
            ChangeNotifierProvider(create: (_) => CommentProvider()),
          ],
          child: MaterialApp(
            title: 'HaHo',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const AuthWrapper(),
          ),
        );
      },
    );
  }
  
  Future<void> _initializeApp() async {
    try {
      // Initialize Firebase
      await FirebaseService.initializeFirebase();
      
      // Initialize notification service
      final notificationService = NotificationService();
      await notificationService.init();
      
      // Schedule reminders for attending events
      final eventService = EventService();
      await eventService.scheduleRemindersForAttendingEvents();
    } catch (e) {
      print('Error during app initialization: $e');
      rethrow;
    }
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Show loading indicator while checking authentication state
    if (authProvider.isLoading) {
      return const SplashScreen();
    }
    
    // For debugging
    print('AuthWrapper: isAuthenticated=${authProvider.isAuthenticated}, isGuest=${authProvider.isGuest}');
    
    // Navigate to home screen if authenticated or guest mode
    if (authProvider.isAuthenticated) {
      print('AuthWrapper: User is authenticated, navigating to HomeScreen');
      return const HomeScreen();
    } else if (authProvider.isGuest) {
      print('AuthWrapper: User is in guest mode, navigating to GuestScreen');
      return const GuestScreen();
    } else {
      print('AuthWrapper: User is not authenticated, navigating to AuthScreen');
      return const AuthScreen();
    }
  }
}
