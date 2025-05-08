import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/comment_provider.dart';
import 'comment_item.dart';
import 'loading_indicator.dart';

class CommentReplyList extends StatelessWidget {
  final String parentCommentId;

  const CommentReplyList({
    Key? key,
    required this.parentCommentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final commentProvider = Provider.of<CommentProvider>(context);
    final replies = commentProvider.replies[parentCommentId];
    final isLoading = commentProvider.isRepliesLoading;

    // If replies are still loading, show loading indicator
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(left: 40, top: 8),
        child: Center(
          child: LoadingIndicator(size: 24),
        ),
      );
    }

    // If no replies yet, show empty state
    if (replies == null || replies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 40, top: 8),
        child: Text('No replies yet.'),
      );
    }

    // Show the list of replies
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: replies.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= replies.length) {
          // Safety check to prevent index out of range errors
          return const SizedBox.shrink();
        }
        return CommentItem(
          comment: replies[index],
          isReply: true,
          onRepliesLoaded: () {
            // Force a rebuild when nested replies are loaded (if needed)
            (context as Element).markNeedsBuild();
          },
        );
      },
    );
  }
} 