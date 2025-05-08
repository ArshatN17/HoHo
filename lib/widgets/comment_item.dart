import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment_model.dart';
import '../providers/comment_provider.dart';
import 'user_avatar.dart';
import 'comment_reply_list.dart';

class CommentItem extends StatefulWidget {
  final CommentModel comment;
  final bool isReply;
  final VoidCallback? onRepliesLoaded;

  const CommentItem({
    Key? key,
    required this.comment,
    this.isReply = false,
    this.onRepliesLoaded,
  }) : super(key: key);

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _isRepliesExpanded = false;
  bool _isOptionsExpanded = false;
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final FocusNode _editFocusNode = FocusNode();

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    _replyFocusNode.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _editController.text = widget.comment.content;
    
    // Pre-load replies for this comment if it has replies
    if (!widget.isReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final commentProvider = Provider.of<CommentProvider>(context, listen: false);
          commentProvider.loadCommentReplies(widget.comment.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentProvider = Provider.of<CommentProvider>(context);
    final currentUserId = commentProvider.currentUserId;
    final isAuthor = currentUserId == widget.comment.authorId;
    final isEditing = commentProvider.editingCommentId == widget.comment.id;
    final isReplying = commentProvider.replyingToId == widget.comment.id;
    final hasReplies = commentProvider.replies.containsKey(widget.comment.id) && 
                      commentProvider.replies[widget.comment.id]!.isNotEmpty;
    
    // If replying to this comment, focus the text field
    if (isReplying && !_replyFocusNode.hasFocus) {
      Future.microtask(() {
        if (mounted) {
          _replyFocusNode.requestFocus();
        }
      });
    }
    
    // If editing this comment, focus the edit field
    if (isEditing && !_editFocusNode.hasFocus) {
      Future.microtask(() {
        if (mounted) {
          _editFocusNode.requestFocus();
        }
      });
    }

    // Pre-load replies if this comment likely has replies
    if (!widget.isReply && !_isRepliesExpanded && (hasReplies || widget.comment.id == commentProvider.replyingToId)) {
      commentProvider.loadCommentReplies(widget.comment.id);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.only(
            left: widget.isReply ? 40 : 0,
            right: 0,
            top: 8,
            bottom: 0,
          ),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment header
                Row(
                  children: [
                    UserAvatar(
                      photoUrl: widget.comment.authorPhotoUrl,
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.comment.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            timeago.format(widget.comment.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isReply)
                      IconButton(
                        icon: Icon(
                          _isOptionsExpanded ? Icons.close : Icons.more_vert,
                          size: 20,
                        ),
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _isOptionsExpanded = !_isOptionsExpanded;
                            });
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Comment content - show either text or edit field
                if (isEditing)
                  TextField(
                    controller: _editController,
                    focusNode: _editFocusNode,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Edit your comment',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _updateComment(),
                  )
                else
                  Text(widget.comment.content),
                
                const SizedBox(height: 8),
                
                // Comment actions (like, reply, edit, delete)
                Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: () {
                        commentProvider.toggleLikeComment(widget.comment.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              currentUserId != null && widget.comment.isLikedBy(currentUserId)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: currentUserId != null && widget.comment.isLikedBy(currentUserId)
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.comment.likeCount.toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Spacer
                    const SizedBox(width: 12),
                    
                    // Reply button
                    if (!isEditing && !widget.isReply)
                      InkWell(
                        onTap: () {
                          commentProvider.setReplyingTo(widget.comment.id);
                          
                          // Always expand replies when replying
                          if (!_isRepliesExpanded) {
                            _isRepliesExpanded = true;
                            setState(() {});
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Comment actions - visible when options expanded or always for replies
                    if (_isOptionsExpanded || widget.isReply)
                      Row(
                        children: [
                          // Edit button (only for own comments)
                          if (isAuthor && !isEditing)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () {
                                // Set the comment being edited
                                commentProvider.setEditingComment(widget.comment.id);
                                _editController.text = widget.comment.content;
                              },
                              tooltip: 'Edit',
                            ),
                            
                          // Delete button (only for own comments)
                          if (isAuthor)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16),
                              onPressed: () => _showDeleteConfirmation(),
                              tooltip: 'Delete',
                            ),
                            
                          // Save button (when editing)
                          if (isEditing)
                            IconButton(
                              icon: const Icon(Icons.check, size: 16),
                              onPressed: _updateComment,
                              tooltip: 'Save',
                            ),
                            
                          // Cancel button (when editing)
                          if (isEditing)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                commentProvider.setEditingComment(null);
                                _editController.text = widget.comment.content;
                              },
                              tooltip: 'Cancel',
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Show a button to view/hide replies if this is a top-level comment
        if (!widget.isReply)
          hasReplies || commentProvider.replyingToId == widget.comment.id
              ? TextButton.icon(
                  icon: Icon(_isRepliesExpanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(
                    _isRepliesExpanded 
                        ? 'Hide replies' 
                        : 'View ${commentProvider.replies[widget.comment.id]?.length ?? 0} replies',
                  ),
                  onPressed: () {
                    if (!_isRepliesExpanded) {
                      // Set to expanded first for better UX
                      setState(() {
                        _isRepliesExpanded = true;
                      });
                      
                      // Then load/refresh replies
                      commentProvider.loadCommentReplies(widget.comment.id).then((_) {
                        if (widget.onRepliesLoaded != null && mounted) {
                          widget.onRepliesLoaded!();
                        }
                      });
                    } else {
                      setState(() {
                        _isRepliesExpanded = false;
                      });
                    }
                  },
                )
              : const SizedBox.shrink(),
        
        // Show replies if expanded
        if (_isRepliesExpanded && !widget.isReply)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: CommentReplyList(parentCommentId: widget.comment.id),
          ),
        
        // Show reply input field if replying to this comment
        if (isReplying && !widget.isReply)
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _submitReply(),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    commentProvider.setReplyingTo(null);
                    _replyController.clear();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  // Helper methods
  void _submitReply() {
    final content = _replyController.text.trim();
    if (content.isNotEmpty) {
      final commentProvider = context.read<CommentProvider>();
      commentProvider.addComment(content, parentId: widget.comment.id);
      _replyController.clear();
    }
  }
  
  void _updateComment() {
    final content = _editController.text.trim();
    if (content.isNotEmpty && mounted) {
      final commentProvider = context.read<CommentProvider>();
      commentProvider.updateComment(widget.comment.id, content);
    }
  }
  
  Future<void> _showDeleteConfirmation() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (shouldDelete == true) {
      if (!mounted) return;
      final commentProvider = context.read<CommentProvider>();
      commentProvider.deleteComment(widget.comment.id);
    }
  }
} 