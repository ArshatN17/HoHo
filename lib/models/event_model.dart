import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String? imageUrl;
  final DateTime date;
  final String location;
  final List<String> tags;
  final List<String> attendees;
  final int maxAttendees;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int reminderMinutes; // How many minutes before the event to send a reminder
  final int commentCount; // Add commentCount field

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    this.imageUrl,
    required this.date,
    required this.location,
    this.tags = const [],
    this.attendees = const [],
    this.maxAttendees = 0, // 0 means unlimited
    required this.createdAt,
    required this.updatedAt,
    this.reminderMinutes = 60, // Default to 1 hour reminder
    this.commentCount = 0, // Default to 0
  });

  // Factory method to create EventModel from Firestore data
  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    return EventModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      creatorId: map['creatorId'] ?? '',
      imageUrl: map['imageUrl'],
      date: (map['date'] as Timestamp).toDate(),
      location: map['location'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      attendees: List<String>.from(map['attendees'] ?? []),
      maxAttendees: map['maxAttendees'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderMinutes: map['reminderMinutes'] ?? 60,
      commentCount: map['commentCount'] ?? 0, // Parse commentCount
    );
  }

  // Convert EventModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'creatorId': creatorId,
      'imageUrl': imageUrl,
      'date': date,
      'location': location,
      'tags': tags,
      'attendees': attendees,
      'maxAttendees': maxAttendees,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'reminderMinutes': reminderMinutes,
      'commentCount': commentCount, // Include commentCount
    };
  }

  // Create a copy of EventModel with updated fields
  EventModel copyWith({
    String? title,
    String? description,
    String? imageUrl,
    DateTime? date,
    String? location,
    List<String>? tags,
    List<String>? attendees,
    int? maxAttendees,
    DateTime? updatedAt,
    int? reminderMinutes,
    int? commentCount,
  }) {
    return EventModel(
      id: this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      creatorId: this.creatorId,
      imageUrl: imageUrl ?? this.imageUrl,
      date: date ?? this.date,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      attendees: attendees ?? this.attendees,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      commentCount: commentCount ?? this.commentCount,
    );
  }
  
  // Check if the event is full
  bool get isFull => maxAttendees > 0 && attendees.length >= maxAttendees;
  
  // Check if a user is attending this event
  bool isUserAttending(String userId) => attendees.contains(userId);
  
  // Check if the event date is in the past
  bool get isPast => date.isBefore(DateTime.now());
  
  // Check if the event date is today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  // Calculate how many spots are left
  int get spotsLeft => maxAttendees > 0 ? maxAttendees - attendees.length : -1; // -1 indicates unlimited
  
  // Format the date as a string
  String get formattedDate => '${date.day}/${date.month}/${date.year}';
  
  // Format the time as a string
  String get formattedTime => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  
  // Calculate reminder time
  DateTime get reminderTime => date.subtract(Duration(minutes: reminderMinutes));
} 