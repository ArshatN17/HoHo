import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/comment_provider.dart';
import '../models/comment_model.dart';
import 'comment_item.dart';
import 'loading_indicator.dart';

class CommentsSection extends StatefulWidget {
  final String eventId;

  const CommentsSection({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Load comments when the widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadComments();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommentProvider>(
      builder: (context, commentProvider, _) {
        final comments = commentProvider.comments;
        final isLoading = commentProvider.isLoading;
        final error = commentProvider.error;
        
        // Calculate comment count from actual comments, not relying on event.commentCount
        final commentCount = comments.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comments section header
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.comment),
                    const SizedBox(width: 8),
                    Text(
                      'Comments ($commentCount)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshComments,
                      tooltip: 'Refresh comments',
                    ),
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            
            // Divider
            const Divider(),
            
            // Comment input field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
            
            // Only show comments if section is expanded
            if (_isExpanded) ...[
              // Loading state
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: LoadingIndicator(),
                  ),
                )
              // Error state
              else if (error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading comments: $error',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                )
              // Empty state
              else if (comments.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No comments yet. Be the first to comment!'),
                  ),
                )
              // Comments list
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return CommentItem(
                      comment: comments[index],
                      onRepliesLoaded: () {
                        // Force rebuild when replies are loaded
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
            ],
          ],
        );
      },
    );
  }

  void _submitComment() {
    final content = _commentController.text.trim();
    if (content.isNotEmpty) {
      final commentProvider = context.read<CommentProvider>();
      commentProvider.addComment(content);
      _commentController.clear();
      
      // Expand the comments section if it's not already expanded
      if (!_isExpanded && mounted) {
        setState(() {
          _isExpanded = true;
        });
      }
    }
  }

  // Extract the comment loading into a separate method
  Future<void> _loadComments() async {
    if (!mounted) return;
    
    final commentProvider = context.read<CommentProvider>();
    await commentProvider.loadEventComments(widget.eventId);
    
    // Auto-expand comments if there are any
    if (commentProvider.comments.isNotEmpty && !_isExpanded) {
      if (mounted) {
        setState(() {
          _isExpanded = true;
        });
      }
    }
  }
  
  // Add a refresh method that can be called when needed
  Future<void> _refreshComments() async {
    if (!mounted) return;
    
    final commentProvider = context.read<CommentProvider>();
    await commentProvider.loadEventComments(widget.eventId);
  }
} 