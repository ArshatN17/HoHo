import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/comment_service.dart';

class EventProvider with ChangeNotifier {
  final EventService _eventService = EventService();
  
  List<EventModel> _events = [];
  EventModel? _selectedEvent;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreEvents = true;
  String? _error;
  DocumentSnapshot? _lastDocument;
  
  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _location;
  List<String>? _tagFilter;
  bool _onlyUpcoming = false;
  bool _onlyPublic = true;
  
  // Available filter options
  List<String> _availableLocations = [];
  List<String> _availableTags = [];
  
  // Getters
  List<EventModel> get events => _events;
  EventModel? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreEvents => _hasMoreEvents;
  String? get error => _error;
  
  // Filter getters
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get location => _location;
  List<String>? get tagFilter => _tagFilter;
  bool get onlyUpcoming => _onlyUpcoming;
  bool get onlyPublic => _onlyPublic;
  List<String> get availableLocations => _availableLocations;
  List<String> get availableTags => _availableTags;
  
  // Add getters for locations and tags (aliases to availableLocations and availableTags)
  List<String> get locations => _availableLocations;
  List<String> get tags => _availableTags;
  
  // Filter setters
  set startDate(DateTime? value) {
    _startDate = value;
    refreshEvents();
  }
  
  set endDate(DateTime? value) {
    _endDate = value;
    refreshEvents();
  }
  
  set location(String? value) {
    _location = value;
    refreshEvents();
  }
  
  set tagFilter(List<String>? value) {
    _tagFilter = value;
    refreshEvents();
  }
  
  set onlyUpcoming(bool value) {
    _onlyUpcoming = value;
    refreshEvents();
  }
  
  set onlyPublic(bool value) {
    _onlyPublic = value;
    refreshEvents();
  }
  
  // Add a single tag to filter
  void addTagToFilter(String tag) {
    if (_tagFilter == null) {
      _tagFilter = [tag];
    } else if (!_tagFilter!.contains(tag)) {
      _tagFilter = [..._tagFilter!, tag];
    }
    refreshEvents();
  }
  
  // Remove a single tag from filter
  void removeTagFromFilter(String tag) {
    if (_tagFilter != null && _tagFilter!.contains(tag)) {
      _tagFilter = _tagFilter!.where((t) => t != tag).toList();
      if (_tagFilter!.isEmpty) _tagFilter = null;
      refreshEvents();
    }
  }
  
  // Clear all filters
  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _location = null;
    _tagFilter = null;
    _onlyUpcoming = false;
    refreshEvents();
  }
  
  // Additional filter getters based on current data
  List<EventModel> get upcomingEvents => 
    _events.where((event) => !event.isPast).toList();
  
  List<EventModel> get pastEvents => 
    _events.where((event) => event.isPast).toList();
  
  List<EventModel> get todayEvents => 
    _events.where((event) => event.isToday).toList();
  
  // Load filter options
  Future<void> loadFilterOptions() async {
    try {
      _availableLocations = await _eventService.getEventLocations();
      _availableTags = await _eventService.getEventTags();
      notifyListeners();
    } catch (e) {
      print('EventProvider: Error loading filter options: $e');
    }
  }
  
  // Refresh events (clear current list and start over)
  Future<void> refreshEvents() async {
    _lastDocument = null;
    _hasMoreEvents = true;
    await loadEvents(
      onlyUpcoming: _onlyUpcoming,
      onlyPublic: _onlyPublic,
      startDate: _startDate,
      endDate: _endDate,
      location: _location,
      tagFilter: _tagFilter,
      clearExisting: true,
    );
  }
  
  // Load more events (pagination)
  Future<void> loadMoreEvents() async {
    if (!_hasMoreEvents || _isLoadingMore) return;
    
    _setLoadingMore(true);
    
    try {
      final newEvents = await _eventService.getEvents(
        onlyUpcoming: _onlyUpcoming,
        onlyPublic: _onlyPublic,
        startDate: _startDate,
        endDate: _endDate,
        location: _location,
        tagFilter: _tagFilter,
        lastDocument: _lastDocument,
      );
      
      if (newEvents.isEmpty) {
        _hasMoreEvents = false;
      } else {
        _events.addAll(newEvents);
        _lastDocument = await _getLastDocumentFromEvent(newEvents.last);
      }
      
      _setLoadingMore(false);
    } catch (e) {
      _setError(e.toString());
      _setLoadingMore(false);
    }
  }
  
  // Get DocumentSnapshot for pagination
  Future<DocumentSnapshot?> _getLastDocumentFromEvent(EventModel event) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .get();
      return snap;
    } catch (e) {
      print('EventProvider: Error getting document snapshot: $e');
      return null;
    }
  }
  
  // Load all events
  Future<void> loadEvents({
    bool onlyUpcoming = false,
    bool onlyPublic = true,
    String? creatorId,
    String? attendeeId,
    List<String>? tagFilter,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    bool clearExisting = false,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      if (clearExisting) {
        _events = [];
        _lastDocument = null;
        _hasMoreEvents = true;
      }
      
      // Modified query strategy to avoid composite index errors
      // First fetch events without the problematic orderBy to avoid index issues
      final loadedEvents = await _eventService.getEvents(
        onlyUpcoming: onlyUpcoming,
        onlyPublic: onlyPublic,
        creatorId: creatorId,
        attendeeId: attendeeId,
        tagFilter: tagFilter,
        location: location,
        startDate: startDate,
        endDate: endDate,
        lastDocument: _lastDocument,
        useOrderBy: false, // Don't use orderBy in the Firestore query
      );
      
      // Sort locally instead to avoid the need for composite indexes
      var sortedEvents = List<EventModel>.from(loadedEvents);
      sortedEvents.sort((a, b) => a.date.compareTo(b.date));
      
      if (sortedEvents.isEmpty) {
        _hasMoreEvents = false;
      } else {
        if (clearExisting) {
          _events = sortedEvents;
        } else {
          _events.addAll(sortedEvents);
        }
        
        if (sortedEvents.isNotEmpty) {
          _lastDocument = await _getLastDocumentFromEvent(sortedEvents.last);
        }
      }
      
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Get a single event
  Future<EventModel?> getEvent(String eventId) async {
    _setLoading(true);
    _error = null;
    
    try {
      _selectedEvent = await _eventService.getEvent(eventId);
      
      // If the event exists, verify its comment count
      if (_selectedEvent != null) {
        // Make a non-nullable copy to pass to _verifyCommentCount
        final event = _selectedEvent!;
        await _verifyCommentCount(event);
      }
      
      _setLoading(false);
      return _selectedEvent;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }
  
  // Helper method to verify and correct the comment count if needed
  Future<void> _verifyCommentCount(EventModel event) async {
    try {
      // Use the comment service to get the actual count
      final commentService = CommentService();
      final actualCount = await commentService.getCommentsCount(event.id);
      
      // If counts don't match, update the event
      if (actualCount != event.commentCount) {
        print('Correcting comment count for event ${event.id}: DB=${event.commentCount}, Actual=$actualCount');
        
        // Update firestore
        await _eventService.updateEventCommentCount(event.id, actualCount);
        
        // Update local model
        if (_selectedEvent != null) {
          _selectedEvent = event.copyWith(commentCount: actualCount);
        }
        
        // Update the event in the events list if it exists there
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          _events[index] = _events[index].copyWith(commentCount: actualCount);
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error verifying comment count: $e');
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
    _setLoading(true);
    _error = null;
    
    try {
      final eventId = await _eventService.createEvent(
        title: title,
        description: description,
        date: date,
        location: location,
        tags: tags,
        imageFile: imageFile,
        maxAttendees: maxAttendees,
        reminderMinutes: reminderMinutes,
      );
      
      // Reload events to include the new one
      if (eventId != null) {
        await refreshEvents();
        await loadFilterOptions(); // Refresh filter options as new tags/location may be available
      }
      
      _setLoading(false);
      return eventId;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
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
    _setLoading(true);
    _error = null;
    
    try {
      final success = await _eventService.updateEvent(
        eventId: eventId,
        title: title,
        description: description,
        date: date,
        location: location,
        tags: tags,
        imageFile: imageFile,
        maxAttendees: maxAttendees,
        reminderMinutes: reminderMinutes,
      );
      
      // Reload the selected event and events list
      if (success) {
        if (_selectedEvent?.id == eventId) {
          await getEvent(eventId);
        }
        await refreshEvents();
        await loadFilterOptions(); // Refresh filter options as tags/location may have changed
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Delete an event
  Future<bool> deleteEvent(String eventId) async {
    _setLoading(true);
    _error = null;
    
    try {
      final success = await _eventService.deleteEvent(eventId);
      
      // Remove from local list if successful
      if (success) {
        _events.removeWhere((event) => event.id == eventId);
        if (_selectedEvent?.id == eventId) {
          _selectedEvent = null;
        }
        notifyListeners();
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Join an event
  Future<bool> joinEvent(String eventId) async {
    _setLoading(true);
    _error = null;
    
    try {
      final success = await _eventService.joinEvent(eventId);
      
      // Update local data if successful
      if (success) {
        // Update selected event if it's the one being joined
        if (_selectedEvent?.id == eventId) {
          await getEvent(eventId);
        }
        
        // Update the event in the list
        final index = _events.indexWhere((event) => event.id == eventId);
        if (index != -1) {
          await refreshEvents(); // Reload events to get updated data
        }
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Leave an event
  Future<bool> leaveEvent(String eventId) async {
    _setLoading(true);
    _error = null;
    
    try {
      final success = await _eventService.leaveEvent(eventId);
      
      // Update local data if successful
      if (success) {
        // Update selected event if it's the one being left
        if (_selectedEvent?.id == eventId) {
          await getEvent(eventId);
        }
        
        // Update the event in the list
        final index = _events.indexWhere((event) => event.id == eventId);
        if (index != -1) {
          await refreshEvents(); // Reload events to get updated data
        }
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Search events
  Future<List<EventModel>> searchEvents(String query) async {
    if (query.isEmpty) return [];
    
    _setLoading(true);
    _error = null;
    
    try {
      final results = await _eventService.searchEvents(query);
      // Update the events list with search results
      _events = results;
      _lastDocument = null; // Reset pagination
      _hasMoreEvents = false; // Disable pagination for search results
      _setLoading(false);
      notifyListeners(); // Notify listeners about the change
      return results;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }
  
  // Get events by tag
  Future<List<EventModel>> getEventsByTag(String tag) async {
    _setLoading(true);
    _error = null;
    
    try {
      final results = await _eventService.getEvents(
        onlyPublic: true,
        tagFilter: [tag],
      );
      _setLoading(false);
      return results;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }
  
  // Helper methods for state management
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setLoadingMore(bool value) {
    _isLoadingMore = value;
    notifyListeners();
  }
  
  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 