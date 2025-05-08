import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'cloudinary_service.dart';
import 'profile_service.dart';
import 'notification_service.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ProfileService _profileService = ProfileService();
  final NotificationService _notificationService = NotificationService();

  // Reference to the events collection
  CollectionReference get _eventsCollection => _firestore.collection('events');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get all events (with optional filters)
  Future<List<EventModel>> getEvents({
    bool onlyUpcoming = false,
    bool onlyPublic = false,
    String? creatorId,
    String? attendeeId,
    List<String>? tagFilter,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    DocumentSnapshot? lastDocument,
    int limit = 10,
    bool useOrderBy = true,
  }) async {
    try {
      Query query = _eventsCollection;

      if (creatorId != null) {
        query = query.where('creatorId', isEqualTo: creatorId);
      }

      if (attendeeId != null) {
        query = query.where('attendees', arrayContains: attendeeId);
      }
      
      // Location filter (exact match)
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }
      
      // Date range filter
      // Note: We can't use multiple range operators in Firestore queries
      // So we'll filter further in code for more complex queries
      if (startDate != null && !onlyUpcoming) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }

      // Only apply orderBy if specified - this helps avoid index errors
      if (useOrderBy) {
        // Order by date
        query = query.orderBy('date', descending: false);
      }
      
      // Pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      // Limit results
      query = query.limit(limit);

      final querySnapshot = await query.get();
      
      List<EventModel> events = querySnapshot.docs.map((doc) {
        return EventModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Filter by date range further in code since Firestore doesn't support multiple range queries
      if (endDate != null) {
        events = events.where((event) => event.date.isBefore(endDate) || event.date.isAtSameMomentAs(endDate)).toList();
      }
      
      // Filter by tags if specified
      if (tagFilter != null && tagFilter.isNotEmpty) {
        events = events.where((event) {
          return tagFilter.any((tag) => event.tags.contains(tag));
        }).toList();
      }

      // Filter upcoming events if needed
      if (onlyUpcoming) {
        final now = DateTime.now();
        events = events.where((event) => event.date.isAfter(now)).toList();
      }

      return events;
    } catch (e) {
      print('EventService: Error getting events: $e');
      rethrow;
    }
  }
  
  // Get list of unique locations for filtering
  Future<List<String>> getEventLocations() async {
    try {
      final querySnapshot = await _eventsCollection.get();
          
      final locations = querySnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['location'] as String)
          .where((location) => location.isNotEmpty)
          .toSet()
          .toList();
      
      return locations;
    } catch (e) {
      print('EventService: Error getting event locations: $e');
      return [];
    }
  }
  
  // Get list of unique tags for filtering
  Future<List<String>> getEventTags() async {
    try {
      final querySnapshot = await _eventsCollection.get();
          
      final Set<String> tagsSet = {};
      
      for (var doc in querySnapshot.docs) {
        final tags = List<String>.from((doc.data() as Map<String, dynamic>)['tags'] ?? []);
        tagsSet.addAll(tags);
      }
      
      return tagsSet.toList();
    } catch (e) {
      print('EventService: Error getting event tags: $e');
      return [];
    }
  }

  // Get a single event by ID
  Future<EventModel?> getEvent(String eventId) async {
    try {
      final docSnapshot = await _eventsCollection.doc(eventId).get();
      
      if (docSnapshot.exists) {
        return EventModel.fromMap(
          docSnapshot.data() as Map<String, dynamic>, 
          docSnapshot.id
        );
      }
      
      return null;
    } catch (e) {
      print('EventService: Error getting event $eventId: $e');
      return null;
    }
  }

  // Create a new event
  Future<String?> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required String location,
    List<String> tags = const [],
    File? imageFile,
    int maxAttendees = 0,
    int reminderMinutes = 60,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // First check if the user has permission to create events
      final userProfile = await _profileService.getUserProfile(currentUserId!);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      if (userProfile.isGuest) {
        throw Exception('Guests cannot create events');
      }
      
      // Upload event image if provided
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _cloudinaryService.uploadImage(
          imageFile,
          'event_images',
          currentUserId!,
        );
      }
      
      final now = DateTime.now();
      
      // Create the event document
      final eventData = EventModel(
        id: '', // This will be set after document creation
        title: title,
        description: description,
        creatorId: currentUserId!,
        imageUrl: imageUrl,
        date: date,
        location: location,
        tags: tags,
        maxAttendees: maxAttendees,
        createdAt: now,
        updatedAt: now,
        reminderMinutes: reminderMinutes,
      ).toMap();
      
      // Add to Firestore
      final docRef = await _eventsCollection.add(eventData);
      
      // Update the user's createdEvents list
      await _firestore.collection('users').doc(currentUserId).update({
        'createdEvents': FieldValue.arrayUnion([docRef.id]),
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      // Automatically join the event as the creator
      await joinEvent(docRef.id, autoJoin: true);
      
      return docRef.id;
    } catch (e) {
      print('EventService: Error creating event: $e');
      rethrow;
    }
  }

  // Update an existing event
  Future<bool> updateEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    List<String>? tags,
    File? imageFile,
    int? maxAttendees,
    int? reminderMinutes,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get the current event data
      final event = await getEvent(eventId);
      if (event == null) {
        throw Exception('Event not found');
      }
      
      // Check if the user is allowed to update the event
      final userProfile = await _profileService.getUserProfile(currentUserId!);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      if (event.creatorId != currentUserId && !userProfile.isAdmin) {
        throw Exception('Not authorized to update this event');
      }
      
      // Upload new image if provided
      String? newImageUrl;
      if (imageFile != null) {
        newImageUrl = await _cloudinaryService.uploadImage(
          imageFile,
          'event_images',
          currentUserId!,
        );
      }
      
      // Update the event document
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (date != null) updateData['date'] = date;
      if (location != null) updateData['location'] = location;
      if (tags != null) updateData['tags'] = tags;
      if (newImageUrl != null) updateData['imageUrl'] = newImageUrl;
      if (maxAttendees != null) updateData['maxAttendees'] = maxAttendees;
      if (reminderMinutes != null) updateData['reminderMinutes'] = reminderMinutes;
      
      await _eventsCollection.doc(eventId).update(updateData);
      
      // If the event date or reminder time changed, reschedule reminders
      if (date != null || reminderMinutes != null) {
        final updatedEvent = await getEvent(eventId);
        if (updatedEvent != null) {
          // Reschedule reminders for all attendees
          // Note: In a production app, this should be handled by a cloud function
          // to update for all attendees, not just the current user
          if (updatedEvent.isUserAttending(currentUserId!)) {
            await _notificationService.rescheduleEventReminder(updatedEvent);
          }
        }
      }
      
      return true;
    } catch (e) {
      print('EventService: Error updating event: $e');
      return false;
    }
  }

  // Delete an event
  Future<bool> deleteEvent(String eventId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get the current event data
      final event = await getEvent(eventId);
      if (event == null) {
        throw Exception('Event not found');
      }
      
      // Check if the user is allowed to delete the event
      final userProfile = await _profileService.getUserProfile(currentUserId!);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      // Only creator or admin can delete events
      if (event.creatorId != currentUserId && !userProfile.isAdmin) {
        throw Exception('Not authorized to delete this event');
      }
      
      // Cancel any scheduled reminders for the current user
      await _notificationService.cancelEventReminder(eventId);
      
      // Delete the event document
      await _eventsCollection.doc(eventId).delete();
      
      // Remove from creator's createdEvents list
      await _firestore.collection('users').doc(event.creatorId).update({
        'createdEvents': FieldValue.arrayRemove([eventId]),
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      // Note: We're not deleting the image from Cloudinary as it might be complex
      // and require additional API calls. In a production app, consider cleaning up resources.
      
      return true;
    } catch (e) {
      print('EventService: Error deleting event: $e');
      return false;
    }
  }

  // Join an event (add user to attendees)
  Future<bool> joinEvent(String eventId, {bool autoJoin = false}) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get the current event data
      final event = await getEvent(eventId);
      if (event == null) {
        throw Exception('Event not found');
      }
      
      // Check if the event is full
      if (event.isFull && !autoJoin) {
        throw Exception('Event is already full');
      }
      
      // Check if the user is already attending
      if (event.isUserAttending(currentUserId!) && !autoJoin) {
        throw Exception('User is already attending this event');
      }
      
      // Add user to attendees
      await _eventsCollection.doc(eventId).update({
        'attendees': FieldValue.arrayUnion([currentUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Schedule a reminder for the event
      final updatedEvent = await getEvent(eventId);
      if (updatedEvent != null && !updatedEvent.isPast) {
        await _notificationService.scheduleEventReminder(updatedEvent);
      }
      
      return true;
    } catch (e) {
      print('EventService: Error joining event: $e');
      return false;
    }
  }

  // Leave an event (remove user from attendees)
  Future<bool> leaveEvent(String eventId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get the current event data
      final event = await getEvent(eventId);
      if (event == null) {
        throw Exception('Event not found');
      }
      
      // Check if the user is attending
      if (!event.isUserAttending(currentUserId!)) {
        throw Exception('User is not attending this event');
      }
      
      // Remove user from attendees
      await _eventsCollection.doc(eventId).update({
        'attendees': FieldValue.arrayRemove([currentUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Cancel any reminder notifications
      await _notificationService.cancelEventReminder(eventId);
      
      return true;
    } catch (e) {
      print('EventService: Error leaving event: $e');
      return false;
    }
  }
  
  // Search events by title, description, or tags
  Future<List<EventModel>> searchEvents(String query) async {
    try {
      if (query.isEmpty) return [];
      
      // Since Firestore doesn't support full text search, we'll use a simple approach
      // In a production app, consider using Algolia or a similar service
      final querySnapshot = await _eventsCollection.get();
      
      final events = querySnapshot.docs
          .map((doc) => EventModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Filter events that contain the query in title, description, or tags
      query = query.toLowerCase();
      return events.where((event) {
        // Check in title and description
        if (event.title.toLowerCase().contains(query) || 
            event.description.toLowerCase().contains(query)) {
          return true;
        }
        
        // Check in tags
        if (event.tags.any((tag) => tag.toLowerCase().contains(query))) {
          return true;
        }
        
        return false;
      }).toList();
    } catch (e) {
      print('EventService: Error searching events: $e');
      return [];
    }
  }
  
  // Schedule reminders for all upcoming events the user is attending
  Future<void> scheduleRemindersForAttendingEvents() async {
    try {
      if (currentUserId == null) return;
      
      final now = DateTime.now();
      
      // Get all upcoming events the user is attending
      final events = await getEvents(
        onlyUpcoming: true,
        attendeeId: currentUserId,
      );
      
      // Schedule reminders for each event
      await _notificationService.scheduleAllEventReminders(events);
      
    } catch (e) {
      print('EventService: Error scheduling reminders: $e');
    }
  }

  // Update an event's comment count directly
  Future<bool> updateEventCommentCount(String eventId, int commentCount) async {
    try {
      await _eventsCollection.doc(eventId).update({
        'commentCount': commentCount,
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('EventService: Error updating event comment count: $e');
      return false;
    }
  }

  // Test sending a reminder notification for an event
  Future<bool> testEventReminderNotification({
    required String userId,
    EventModel? event,
    String? eventId,
    String? eventTitle,
  }) async {
    try {
      // If no event is provided but we have an ID, fetch the event
      if (event == null && eventId != null) {
        event = await getEvent(eventId);
      }
      
      // Create a mock event if we don't have a real one
      if (event == null) {
        final now = DateTime.now();
        final testEventTime = now.add(const Duration(hours: 1));
        event = EventModel(
          id: eventId ?? 'test_event_${DateTime.now().millisecondsSinceEpoch}',
          title: eventTitle ?? 'Test Event',
          description: 'This is a test event to verify notifications are working',
          creatorId: userId,
          date: testEventTime,
          location: 'Test Location',
          createdAt: now,
          updatedAt: now,
          reminderMinutes: 30, // Remind 30 minutes before
        );
      }
      
      // For test notifications, we want to show them immediately
      return await _notificationService.sendTestEventNotification(
        userId: userId,
        title: 'Event Reminder: ${event.title}',
        body: 'Your event "${event.title}" starts ${_formatEventTime(event.date)}',
        additionalData: {
          'eventId': event.id,
          'eventTitle': event.title,
          'eventDate': event.formattedDate,
          'eventTime': event.formattedTime,
          'eventLocation': event.location,
          'isTestNotification': true,
        },
      );
    } catch (e) {
      print('Error testing event reminder: $e');
      return false;
    }
  }
  
  // Helper to format event time for notifications
  String _formatEventTime(DateTime eventTime) {
    final now = DateTime.now();
    final difference = eventTime.difference(now);
    
    if (difference.inHours < 1) {
      return 'in ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours} hours';
    } else {
      return 'on ${eventTime.day}/${eventTime.month} at ${eventTime.hour}:${eventTime.minute.toString().padLeft(2, '0')}';
    }
  }
} 