import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';

class CommentProvider with ChangeNotifier {
  final CommentService _commentService = CommentService();
  
  // Add a getter for the comment service
  CommentService get commentService => _commentService;
  
  // Add a getter for current user ID
  String? get currentUserId => _commentService.currentUserId;
  
  // State variables
  List<CommentModel> _comments = [];
  Map<String, List<CommentModel>> _replies = {};
  String? _currentEventId;
  bool _isLoading = false;
  bool _isRepliesLoading = false;
  String? _error;
  String? _replyingToId; // ID of comment being replied to, null if not replying
  String? _editingCommentId; // ID of comment being edited
  
  // Getters
  List<CommentModel> get comments => _comments;
  Map<String, List<CommentModel>> get replies => _replies;
  bool get isLoading => _isLoading;
  bool get isRepliesLoading => _isRepliesLoading;
  String? get error => _error;
  String? get replyingToId => _replyingToId;
  String? get editingCommentId => _editingCommentId;
  
  // Helper functions to manage replying state
  void setReplyingTo(String? commentId) {
    _replyingToId = commentId;
    notifyListeners();
  }
  
  void setEditingComment(String? commentId) {
    _editingCommentId = commentId;
    notifyListeners();
  }
  
  // Get CommentModel by ID
  CommentModel? getCommentById(String id) {
    try {
      return _comments.firstWhere((comment) => comment.id == id);
    } catch (e) {
      // Look in replies
      for (var replyList in _replies.values) {
        try {
          return replyList.firstWhere((comment) => comment.id == id);
        } catch (e) {
          // Not found in this reply list
          continue;
        }
      }
      return null;
    }
  }
  
  // Load comments for an event
  Future<void> loadEventComments(String eventId) async {
    _setLoading(true);
    _currentEventId = eventId;
    _error = null;
    
    try {
      // Clear existing comments and replies to avoid duplicates
      _comments = [];
      _replies = {};
      
      // Load comments with retries to handle potential network issues
      int retryCount = 0;
      const maxRetries = 3;
      List<CommentModel>? loadedComments;
      
      while (retryCount < maxRetries && (loadedComments == null || loadedComments.isEmpty)) {
        try {
          loadedComments = await _commentService.getEventComments(eventId);
          if (loadedComments.isEmpty && retryCount < maxRetries - 1) {
            // Wait a bit before retrying
            await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          }
        } catch (e) {
          print('Error loading comments (attempt ${retryCount + 1}): $e');
          if (retryCount >= maxRetries - 1) {
            rethrow; // Re-throw on the last attempt
          }
          // Wait before retrying
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        }
        retryCount++;
      }
      
      if (loadedComments != null) {
        _comments = loadedComments;
      }
      
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Load replies for a comment
  Future<void> loadCommentReplies(String commentId) async {
    // Always set loading state to give visual feedback
    _setRepliesLoading(true);
    
    try {
      // Always fetch fresh replies to ensure we have the latest data
      final replies = await _commentService.getCommentReplies(commentId);
      
      // Update the replies map
      _replies[commentId] = replies;
      
      _setRepliesLoading(false);
    } catch (e) {
      print('Error loading replies for comment $commentId: $e');
      _setError(e.toString());
      _setRepliesLoading(false);
    }
  }
  
  // Add a new comment
  Future<CommentModel?> addComment(String content, {String? parentId}) async {
    _error = null;
    
    try {
      if (_currentEventId == null) {
        throw Exception('No event selected');
      }
      
      final newComment = await _commentService.addComment(
        eventId: _currentEventId!,
        content: content,
        parentId: parentId,
      );
      
      if (newComment != null) {
        if (parentId == null) {
          // Top level comment
          _comments.insert(0, newComment); // Add to beginning since sorted by newest first
        } else {
          // Reply to another comment
          if (_replies.containsKey(parentId)) {
            _replies[parentId]!.add(newComment);
          } else {
            _replies[parentId] = [newComment];
          }
          
          // Clear replying state
          _replyingToId = null;
        }
        
        notifyListeners();
      }
      
      return newComment;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }
  
  // Update a comment
  Future<bool> updateComment(String commentId, String content) async {
    _error = null;
    
    try {
      final success = await _commentService.updateComment(
        commentId: commentId,
        content: content,
      );
      
      if (success) {
        // Update the comment in our local state
        final comment = getCommentById(commentId);
        if (comment != null) {
          final index = _findCommentIndex(commentId);
          if (index != null) {
            // Top level comment
            _comments[index] = comment.copyWith(content: content);
          } else {
            // Check in replies
            for (var parentId in _replies.keys) {
              final replyIndex = _findReplyIndex(parentId, commentId);
              if (replyIndex != null) {
                _replies[parentId]![replyIndex] = _replies[parentId]![replyIndex].copyWith(content: content);
                break;
              }
            }
          }
        }
        
        // Clear editing state
        _editingCommentId = null;
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Delete a comment
  Future<bool> deleteComment(String commentId) async {
    _error = null;
    
    try {
      final success = await _commentService.deleteComment(commentId);
      
      if (success) {
        // Check if it's a top-level comment
        final index = _findCommentIndex(commentId);
        if (index != null) {
          // Remove the comment and its replies
          _comments.removeAt(index);
          _replies.remove(commentId);
        } else {
          // Check in replies
          for (var parentId in _replies.keys) {
            final replyIndex = _findReplyIndex(parentId, commentId);
            if (replyIndex != null) {
              _replies[parentId]!.removeAt(replyIndex);
              break;
            }
          }
        }
        
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Like or unlike a comment
  Future<bool> toggleLikeComment(String commentId) async {
    _error = null;
    
    try {
      final success = await _commentService.toggleLikeComment(commentId);
      
      if (success) {
        // Update the UI optimistically while we wait for Firestore to sync
        final userId = _commentService.currentUserId;
        if (userId != null) {
          // Check if it's a top-level comment
          final index = _findCommentIndex(commentId);
          if (index != null) {
            final comment = _comments[index];
            List<String> updatedLikes = List.from(comment.likes);
            
            if (comment.isLikedBy(userId)) {
              updatedLikes.remove(userId);
            } else {
              updatedLikes.add(userId);
            }
            
            _comments[index] = comment.copyWith(likes: updatedLikes);
          } else {
            // Check in replies
            for (var parentId in _replies.keys) {
              final replyIndex = _findReplyIndex(parentId, commentId);
              if (replyIndex != null) {
                final reply = _replies[parentId]![replyIndex];
                List<String> updatedLikes = List.from(reply.likes);
                
                if (reply.isLikedBy(userId)) {
                  updatedLikes.remove(userId);
                } else {
                  updatedLikes.add(userId);
                }
                
                _replies[parentId]![replyIndex] = reply.copyWith(likes: updatedLikes);
                break;
              }
            }
          }
          
          notifyListeners();
        }
      }
      
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Helper methods
  
  // Find the index of a comment in the main comments list
  int? _findCommentIndex(String commentId) {
    try {
      return _comments.indexWhere((comment) => comment.id == commentId);
    } catch (e) {
      return null;
    }
  }
  
  // Find the index of a reply in the replies map
  int? _findReplyIndex(String parentId, String replyId) {
    try {
      if (_replies.containsKey(parentId)) {
        return _replies[parentId]!.indexWhere((reply) => reply.id == replyId);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // State management helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setRepliesLoading(bool value) {
    _isRepliesLoading = value;
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