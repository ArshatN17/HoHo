import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import 'firebase_service.dart';
import 'profile_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  final ProfileService _profileService = ProfileService();

  // Collection references
  CollectionReference get _commentsCollection => _firestore.collection('comments');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get comments for a specific event
  Future<List<CommentModel>> getEventComments(String eventId, {bool topLevelOnly = true}) async {
    try {
      Query query = _commentsCollection
          .where('eventId', isEqualTo: eventId);
      
      if (topLevelOnly) {
        query = query.where('parentId', isNull: true);
      }
      
      // Use a simpler query that doesn't require complex indexes
      // query = query.orderBy('createdAt', descending: true);
      
      final querySnapshot = await query.get();
      
      // Sort the results in memory instead of in the query
      final comments = querySnapshot.docs.map((doc) {
        return CommentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort in memory by creation time (descending order - newest first)
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return comments;
    } catch (e) {
      print('CommentService: Error getting event comments: $e');
      return [];
    }
  }

  // Get replies to a specific comment
  Future<List<CommentModel>> getCommentReplies(String commentId) async {
    try {
      print('Fetching replies for comment: $commentId');
      
      final querySnapshot = await _commentsCollection
          .where('parentId', isEqualTo: commentId)
          // .orderBy('createdAt', descending: false)
          .get();
      
      print('Found ${querySnapshot.docs.length} replies for comment $commentId');
      
      // Sort in memory instead of in the query
      final replies = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('Reply data: ${doc.id} - parent: ${data['parentId']}');
        return CommentModel.fromMap(data, doc.id);
      }).toList();
      
      // Sort by creation time (ascending order - oldest first for replies)
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return replies;
    } catch (e) {
      print('CommentService: Error getting comment replies: $e');
      return [];
    }
  }

  // Add a new comment
  Future<CommentModel?> addComment({
    required String eventId,
    required String content,
    String? parentId,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get user profile to include name and photo URL
      final userProfile = await _profileService.getUserProfile(currentUserId!);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      final now = DateTime.now(); // Use a concrete DateTime instead of serverTimestamp
      
      final comment = CommentModel(
        id: '',
        content: content,
        authorId: currentUserId!,
        authorName: userProfile.getFullName(),
        authorPhotoUrl: userProfile.photoURL,
        eventId: eventId,
        createdAt: now,
        likes: [],
        parentId: parentId,
      );
      
      // Convert to map but handle the timestamp explicitly
      final commentData = comment.toMap();
      
      // Begin a Firestore transaction for consistency
      final result = await _firestore.runTransaction<DocumentReference>((transaction) async {
        // First get the event document to check its current count
        final eventDoc = await transaction.get(_firestore.collection('events').doc(eventId));
        
        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }
        
        // Create the comment document
        final docRef = _commentsCollection.doc();
        
        // Set the comment data
        transaction.set(docRef, commentData);
        
        // Only update the count for top-level comments
        if (parentId == null) {
          final currentCount = eventDoc.data()?['commentCount'] ?? 0;
          transaction.update(_firestore.collection('events').doc(eventId), {
            'commentCount': currentCount + 1,
            'updatedAt': now,
          });
        }
        
        return docRef;
      });
      
      // Return the created comment with the generated ID
      return CommentModel.fromMap(commentData, result.id);
    } catch (e) {
      print('CommentService: Error adding comment: $e');
      return null;
    }
  }

  // Update a comment
  Future<bool> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Check if the user is the author of the comment
      final docSnapshot = await _commentsCollection.doc(commentId).get();
      if (!docSnapshot.exists) {
        throw Exception('Comment not found');
      }
      
      final commentData = docSnapshot.data() as Map<String, dynamic>;
      if (commentData['authorId'] != currentUserId) {
        throw Exception('You can only edit your own comments');
      }
      
      await _commentsCollection.doc(commentId).update({
        'content': content,
        'updatedAt': DateTime.now(), // Use actual DateTime instead of FieldValue
      });
      
      return true;
    } catch (e) {
      print('CommentService: Error updating comment: $e');
      return false;
    }
  }

  // Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Begin a Firestore transaction for consistency
      return await _firestore.runTransaction<bool>((transaction) async {
        // STEP 1: Perform all reads first
        
        // 1. Read the comment document
        final docSnapshot = await transaction.get(_commentsCollection.doc(commentId));
        
        if (!docSnapshot.exists) {
          throw Exception('Comment not found');
        }
        
        final commentData = docSnapshot.data() as Map<String, dynamic>;
        
        // 2. Check user permissions
        final userProfile = await _profileService.getUserProfile(currentUserId!);
        if (userProfile == null) {
          throw Exception('User profile not found');
        }
        
        if (commentData['authorId'] != currentUserId && !userProfile.isAdmin) {
          throw Exception('You can only delete your own comments');
        }
        
        // 3. Get event ID and parent ID
        final eventId = commentData['eventId'] as String;
        final parentId = commentData['parentId'] as String?;
        
        // 4. Check if this comment has replies
        final repliesSnapshot = await _firestore.collection('comments')
            .where('parentId', isEqualTo: commentId)
            .get();
        
        final replyDocs = repliesSnapshot.docs;
        
        // 5. Get the event document if needed
        DocumentSnapshot? eventDoc;
        if (parentId == null) {
          eventDoc = await transaction.get(_firestore.collection('events').doc(eventId));
        }
        
        // STEP 2: Now perform all writes
        
        // 1. Delete all replies first
        for (var replyDoc in replyDocs) {
          transaction.delete(replyDoc.reference);
        }
        
        // 2. Delete the main comment
        transaction.delete(_commentsCollection.doc(commentId));
        
        // 3. Update the count if this was a top-level comment
        if (parentId == null && eventDoc != null && eventDoc.exists) {
          // Access the data as a Map explicitly
          final data = eventDoc.data() as Map<String, dynamic>?;
          final currentCount = data?['commentCount'] as int? ?? 0;
          
          // Ensure the count doesn't go below zero
          final newCount = (currentCount - 1 - replyDocs.length) < 0 
              ? 0 
              : (currentCount - 1 - replyDocs.length);
              
          transaction.update(_firestore.collection('events').doc(eventId), {
            'commentCount': newCount,
            'updatedAt': DateTime.now(),
          });
        }
        
        return true;
      });
    } catch (e) {
      print('CommentService: Error deleting comment: $e');
      return false;
    }
  }

  // Like or unlike a comment
  Future<bool> toggleLikeComment(String commentId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final docSnapshot = await _commentsCollection.doc(commentId).get();
      if (!docSnapshot.exists) {
        throw Exception('Comment not found');
      }
      
      final commentData = docSnapshot.data() as Map<String, dynamic>;
      final likes = List<String>.from(commentData['likes'] ?? []);
      
      if (likes.contains(currentUserId)) {
        // Unlike the comment
        await _commentsCollection.doc(commentId).update({
          'likes': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        // Like the comment
        await _commentsCollection.doc(commentId).update({
          'likes': FieldValue.arrayUnion([currentUserId]),
        });
      }
      
      return true;
    } catch (e) {
      print('CommentService: Error toggling like comment: $e');
      return false;
    }
  }

  // Get comments count for an event (to ensure UI is in sync with actual count)
  Future<int> getCommentsCount(String eventId) async {
    try {
      final querySnapshot = await _commentsCollection
          .where('eventId', isEqualTo: eventId)
          .where('parentId', isNull: true)
          .get();
      
      return querySnapshot.size;
    } catch (e) {
      print('CommentService: Error getting comments count: $e');
      return 0;
    }
  }
} 