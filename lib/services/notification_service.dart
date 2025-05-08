import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/event_model.dart';
import 'firebase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // Key for storing notification settings in shared preferences
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _remindersEnabledKey = 'reminders_enabled';
  
  Future<void> init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();
    
    print('Initializing notification service');
    
    // Initialize notification settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
    
    // Create notification channels explicitly for Android
    if (Platform.isAndroid) {
      print('Creating notification channels for Android');
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'event_reminders', 
          'Event Reminders',
          description: 'Reminds you about upcoming events',
          importance: Importance.max,
        ),
      );
      
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'test_notifications', 
          'Test Notifications',
          description: 'Used for testing notifications',
          importance: Importance.max,
        ),
      );
      
      // Check if notifications are enabled
      final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
      print('Android notifications enabled: $areNotificationsEnabled');
      
      if (areNotificationsEnabled == false) {
        print('Need to request notification permission on Android');
      }
    }
    
    // Request permissions for iOS
    if (Platform.isIOS) {
      print('Requesting iOS permissions');
      final iosImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    
    print('Notification service initialization complete');
  }
  
  // Handle notification tap
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Navigation would be handled here
    // Example:
    // if (response.payload != null) {
    //   NavigationService.navigateTo('/event/${response.payload}');
    // }
  }
  
  // Schedule a notification for an event
  Future<void> scheduleEventReminder(EventModel event) async {
    // Check if reminders are enabled
    if (!await areRemindersEnabled()) return;
    
    // Calculate reminder time
    final reminderTime = event.reminderTime;
    if (reminderTime.isBefore(DateTime.now())) {
      print('Reminder time is in the past, not scheduling');
      return;
    }
    
    print('Scheduling reminder for event ${event.id} at $reminderTime');
    
    // Define Android notification details
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription: 'Reminds you about upcoming events',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    // Define iOS notification details
    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    // Combine platform-specific details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );
    
    final formattedMessage = 'Event starts ${_formatReminderTime(reminderTime, event.date)}';
    
    // Schedule the notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      event.id.hashCode, // Use event ID as notification ID
      event.title,
      formattedMessage,
      tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: event.id,
    );
    
    // Store reminder in Firestore for tracking
    final currentUser = FirebaseService.auth.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseService.firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('reminders')
            .doc(event.id)
            .set({
          'eventId': event.id,
          'reminderTime': reminderTime,
          'title': event.title,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error storing reminder: $e');
      }
    }
  }
  
  // Format reminder time string
  String _formatReminderTime(DateTime reminderTime, DateTime eventTime) {
    final difference = eventTime.difference(reminderTime);
    if (difference.inMinutes <= 30) {
      return 'in ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours} hours';
    } else {
      return 'on ${eventTime.day}/${eventTime.month}/${eventTime.year}';
    }
  }
  
  // Cancel a scheduled notification
  Future<void> cancelEventReminder(String eventId) async {
    await _flutterLocalNotificationsPlugin.cancel(eventId.hashCode);
    
    final currentUser = FirebaseService.auth.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseService.firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('reminders')
            .doc(eventId)
            .delete();
            
        print('Cancelled reminder for event $eventId');
      } catch (e) {
        print('Error cancelling reminder: $e');
      }
    }
  }
  
  // Reschedule a reminder
  Future<void> rescheduleEventReminder(EventModel event) async {
    await cancelEventReminder(event.id);
    await scheduleEventReminder(event);
  }
  
  // Schedule reminders for all events
  Future<void> scheduleAllEventReminders(List<EventModel> events) async {
    for (final event in events) {
      if (!event.isPast) {
        await scheduleEventReminder(event);
      }
    }
  }
  
  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }
  
  // Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }
  
  // Check if reminders are enabled
  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersEnabledKey) ?? true;
  }
  
  // Set reminders enabled/disabled
  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, enabled);
  }
  
  // Send an immediate test notification
  Future<bool> sendTestEventNotification({
    required String userId,
    String title = 'Test Event Notification',
    String body = 'This is a test notification for an upcoming event',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('Attempting to send test notification to user $userId');
      
      // Проверка разрешений на Android
      if (Platform.isAndroid) {
        final androidImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
        print('Android notifications enabled: $areNotificationsEnabled');
        
        if (areNotificationsEnabled == false) {
          print('Requesting notification permission on Android');
          await androidImplementation?.requestNotificationsPermission();
        }
      }
      
      // Define notification details
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'test_notifications',
        'Test Notifications',
        channelDescription: 'Used for testing notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      
      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );
      
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      print('Showing notification with ID: $notificationId');
      
      // Show the notification immediately
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'test_notification',
      );
      
      // Create a record in Firestore
      final currentUser = FirebaseService.auth.currentUser;
      if (currentUser != null) {
        await FirebaseService.firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'data': additionalData ?? {},
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('Test notification sent to user $userId successfully');
      return true;
    } catch (e) {
      print('Error sending test notification: $e');
      return false;
    }
  }
} 