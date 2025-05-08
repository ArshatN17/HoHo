import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/event_service.dart';
import '../services/firebase_service.dart';
import '../models/event_model.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final EventService eventService = EventService();
  
  bool _notificationsEnabled = true;
  bool _remindersEnabled = true;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _notificationsEnabled = await _notificationService.areNotificationsEnabled();
      _remindersEnabled = await _notificationService.areRemindersEnabled();
    } catch (e) {
      print('Error loading notification settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    
    try {
      await _notificationService.setNotificationsEnabled(value);
      // If turning off notifications, also turn off reminders
      if (!value && _remindersEnabled) {
        await _toggleReminders(false);
      }
    } catch (e) {
      // Revert state if failed
      setState(() {
        _notificationsEnabled = !value;
      });
    }
  }
  
  Future<void> _toggleReminders(bool value) async {
    // Can't enable reminders if notifications are disabled
    if (value && !_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable notifications first')),
      );
      return;
    }
    
    setState(() {
      _remindersEnabled = value;
    });
    
    try {
      await _notificationService.setRemindersEnabled(value);
    } catch (e) {
      // Revert state if failed
      setState(() {
        _remindersEnabled = !value;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseService.auth.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              // Notifications section
              _buildSection(
                title: 'Notifications',
                icon: Icons.notifications,
                children: [
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text('Get notified about events and updates'),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  if (_notificationsEnabled)
                    SwitchListTile(
                      title: const Text('Event Reminders'),
                      subtitle: const Text('Get reminders for events you\'re attending'),
                      value: _remindersEnabled,
                      onChanged: _toggleReminders,
                    ),
                  if (_notificationsEnabled && currentUser != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Test Notification'),
                            onPressed: _sendTestNotification,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.alarm),
                            label: const Text('Test Reminder'),
                            onPressed: _sendTestReminderNotification,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              // Explanation
              _buildSection(
                title: 'About Notifications',
                icon: Icons.info_outline,
                children: [
                  ListTile(
                    title: Text('Notification Types'),
                    subtitle: Text(
                      'You may receive notifications about new events, event updates, '
                      'and reminders for events you\'re attending.'
                    ),
                  ),
                  const Divider(),
                  const ListTile(
                    subtitle: Text(
                      'You can also manage notifications through your device settings. '
                      'These settings only control in-app notifications.',
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
  
  // Function to send a test notification
  Future<void> _sendTestNotification() async {
    final currentUser = FirebaseService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to test notifications')),
      );
      return;
    }
    
    try {
      final success = await eventService.testEventReminderNotification(
        userId: currentUser.uid,
        eventTitle: 'Test Notification',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
              ? 'Test notification sent successfully!'
              : 'Failed to send test notification'
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending test notification: $e')),
        );
      }
    }
  }
  
  // Function to send a test reminder notification with a scheduled time
  Future<void> _sendTestReminderNotification() async {
    final currentUser = FirebaseService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to test notifications')),
      );
      return;
    }
    
    try {
      // Create a test event that will happen in 30 seconds from now
      final now = DateTime.now();
      final testEventTime = now.add(const Duration(minutes: 5));
      final event = EventModel(
        id: 'test_reminder_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Scheduled Reminder',
        description: 'This is a test event with a scheduled reminder',
        creatorId: currentUser.uid,
        date: testEventTime,
        location: 'Test Location',
        createdAt: now,
        updatedAt: now,
        reminderMinutes: 4, // Remind in 1 minute from now (5-4=1)
      );
      
      // Schedule the reminder
      await _notificationService.scheduleEventReminder(event);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test reminder scheduled for 1 minute from now'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling test reminder: $e')),
        );
      }
    }
  }
} 