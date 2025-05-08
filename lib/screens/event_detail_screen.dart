import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/event_provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/loading_indicator.dart';
import '../models/event_model.dart';
import 'edit_event_screen.dart';
import '../widgets/comments_section.dart';
import 'auth_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final bool isGuestMode;
  
  const EventDetailScreen({
    Key? key,
    required this.eventId,
    this.isGuestMode = false,
  }) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }
  
  Future<void> _loadEventDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      await eventProvider.getEvent(widget.eventId);
    } catch (e) {
      print('EventDetailScreen: Error loading event details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _navigateToEditScreen(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(eventId: widget.eventId),
      ),
    );
    
    if (result == true && mounted) {
      _loadEventDetails(); // Reload event details if edited
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          final event = eventProvider.selectedEvent;
          final isLoading = eventProvider.isLoading;
          final error = eventProvider.error;
          
          if (isLoading || eventProvider.isLoading) {
            return const LoadingIndicator(message: 'Loading event details...');
          }
          
          if (error != null) {
            return Center(child: Text('Error: $error'));
          }
          
          if (event == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Event not found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The event may have been deleted or is no longer available',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          
          final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
          final timeFormat = DateFormat('h:mm a');
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final isCreator = authProvider.user?.uid == event.creatorId;
          final isAttending = event.attendees.contains(authProvider.user?.uid);
          final isGuestMode = widget.isGuestMode || authProvider.isGuest;
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event image
                if (event.imageUrl != null)
                  Hero(
                    tag: 'event_image_${event.id}',
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error, size: 48),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 150,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: Icon(
                      Icons.event,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                
                // Event details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCreator && !isGuestMode)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _navigateToEditScreen(context),
                              tooltip: 'Edit Event',
                              iconSize: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Date & Time
                      Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormat.format(event.date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: event.isPast
                                      ? Colors.red
                                      : event.isToday
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                ),
                              ),
                              Text(
                                timeFormat.format(event.date),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.location,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Attendance
                      Row(
                        children: [
                          const Icon(Icons.people),
                          const SizedBox(width: 8),
                          Text(
                            '${event.attendees.length} attending${event.maxAttendees > 0 ? ' (${event.spotsLeft >= 0 ? event.spotsLeft : "unlimited"} spots left)' : ''}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: event.isFull ? FontWeight.bold : null,
                              color: event.isFull ? Colors.red : null,
                            ),
                          ),
                        ],
                      ),
                      
                      // Reminder time
                      if (isAttending && !event.isPast) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.alarm),
                            const SizedBox(width: 8),
                            Text(
                              'Reminder: ${_formatReminderTime(event.reminderMinutes)} before event',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Reschedule reminder',
                              onPressed: () => _rescheduleReminder(event),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Description
                      const Text(
                        'About this event',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        style: const TextStyle(fontSize: 16),
                      ),
                      
                      // Tags
                      if (event.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: event.tags.map((tag) {
                            return Chip(
                              label: Text(
                                tag,
                                style: TextStyle(
                                  color: Theme.of(context).chipTheme.labelStyle?.color,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              elevation: 1,
                            );
                          }).toList(),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Join/Leave buttons
                      if (!event.isPast)
                        SizedBox(
                          width: double.infinity,
                          child: isGuestMode
                              ? ElevatedButton.icon(
                                  onPressed: () => _showLoginPrompt(context),
                                  icon: const Icon(Icons.login),
                                  label: const Text('Sign in to Join Event'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                )
                              : isCreator
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _navigateToEditScreen(context),
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit Event'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Event?'),
                                                  content: const Text('This action cannot be undone. Are you sure you want to delete this event?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('CANCEL'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('DELETE'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            
                                              if (confirm == true) {
                                                final success = await eventProvider.deleteEvent(event.id);
                                                if (success && mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Event deleted successfully')),
                                                  );
                                                  Navigator.pop(context);
                                                }
                                              }
                                            },
                                            icon: const Icon(Icons.delete),
                                            label: const Text('Delete Event'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : isAttending
                                      ? ElevatedButton.icon(
                                          onPressed: () async {
                                            final success = await eventProvider.leaveEvent(event.id);
                                            if (success && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('You are no longer attending this event')),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.exit_to_app),
                                          label: const Text('Leave Event'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () async {
                                            final success = await eventProvider.joinEvent(event.id);
                                            if (success && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('You are now attending this event')),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.check),
                                          label: const Text('Join Event'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                        ),
                      
                      // Remove the separate delete button since we've integrated it with edit
                      if (isCreator && event.isPast) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Event?'),
                                  content: const Text('This action cannot be undone. Are you sure you want to delete this event?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('CANCEL'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                final success = await eventProvider.deleteEvent(event.id);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Event deleted successfully')),
                                  );
                                  Navigator.pop(context);
                                }
                              }
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete Event'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Add comments section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isGuestMode
                    ? _buildGuestCommentsSection(context)
                    : CommentsSection(eventId: event.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildGuestCommentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Sign in to see and post comments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the conversation by creating an account or signing in',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showLoginPrompt(context),
                child: const Text('SIGN IN'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to format reminder time
  String _formatReminderTime(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes == 60) {
      return '1 hour';
    } else if (minutes < 1440) {
      return '${minutes ~/ 60} hours';
    } else {
      return '${minutes ~/ 1440} days';
    }
  }
  
  // Method to reschedule a reminder
  Future<void> _rescheduleReminder(EventModel event) async {
    final notificationService = NotificationService();
    
    try {
      await notificationService.rescheduleEventReminder(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder rescheduled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rescheduling reminder: $e')),
        );
      }
    }
  }
  
  // Method to show login prompt
  Future<void> _showLoginPrompt(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text(
          'To join events, comment, and interact with other users, you need to create an account or sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CONTINUE BROWSING'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              _navigateToAuth(context);
            },
            child: const Text('SIGN IN'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      _navigateToAuth(context);
    }
  }
  
  // Navigate to auth screen
  void _navigateToAuth(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // This will exit guest mode
    authProvider.logout();
  }
} 