import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String eventId;
  final DateTime createdAt;
  final List<String> likes;
  final String? parentId; // For threaded replies - null means top level comment

  CommentModel({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.eventId,
    required this.createdAt,
    required this.likes,
    this.parentId,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle the createdAt timestamp more robustly
    DateTime createdAt;
    final createdAtData = map['createdAt'];
    
    if (createdAtData is Timestamp) {
      createdAt = createdAtData.toDate();
    } else if (createdAtData is DateTime) {
      createdAt = createdAtData;
    } else {
      createdAt = DateTime.now(); // Fallback
    }
    
    return CommentModel(
      id: id,
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'],
      eventId: map['eventId'] ?? '',
      createdAt: createdAt,
      likes: List<String>.from(map['likes'] ?? []),
      parentId: map['parentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'eventId': eventId,
      'createdAt': createdAt,
      'likes': likes,
      'parentId': parentId,
    };
  }

  bool get isReply => parentId != null;
  bool isLikedBy(String userId) => likes.contains(userId);
  int get likeCount => likes.length;

  CommentModel copyWith({
    String? id,
    String? content,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? eventId,
    DateTime? createdAt,
    List<String>? likes,
    String? parentId,
  }) {
    return CommentModel(
      id: id ?? this.id,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      parentId: parentId ?? this.parentId,
    );
  }
} 