import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_moderation_service.dart';

// ============== COMMUNITY FORUM (Reddit-like) ==============

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({super.key});

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> {
  String _sortBy = 'hot'; // hot, new, top
  List<ForumPost> _posts = [];
  final List<String> _availableTags = ['Support', 'Treatment', 'Diet', 'Exercise', 'Symptoms', 'Lifestyle', 'Question', 'NewDiagnosis', 'Medication', 'Mental Health'];

  @override
  Widget build(BuildContext context) {
    // Sort posts
    final sortedPosts = List<ForumPost>.from(_posts);
    if (_sortBy == 'hot') {
      sortedPosts.sort((a, b) => b.score.compareTo(a.score));
    } else if (_sortBy == 'new') {
      sortedPosts.sort((a, b) => b.postedTime.compareTo(a.postedTime));
    } else if (_sortBy == 'top') {
      sortedPosts.sort((a, b) => (b.upvotes - b.downvotes).compareTo(a.upvotes - a.downvotes));
    }

    return Scaffold(
      body: Column(
        children: [
          // Sorting and filter options
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortButton('Hot', 'hot'),
                        const SizedBox(width: 8),
                        _buildSortButton('New', 'new'),
                        const SizedBox(width: 8),
                        _buildSortButton('Top', 'top'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          // Posts list
          Expanded(
            child: ListView.builder(
              itemCount: sortedPosts.length,
              itemBuilder: (context, index) {
                return _buildPostCard(sortedPosts[index], index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostDialog(),
        label: const Text('New Post'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white
      ),
    );
  }

  Widget _buildSortButton(String label, String sortValue) {
    final isActive = _sortBy == sortValue;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.pink : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      onPressed: () => setState(() => _sortBy = sortValue),
      child: Text(label),
    );
  }

  Widget _buildPostCard(ForumPost post, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ForumPostPage(post: post)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author and timestamp
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.pink[100],
                    child: Text(post.author[0].toUpperCase(), style: TextStyle(color: Colors.pink[700], fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('u/${post.author}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Text('${post.timeAgo}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        Text('r/PCOS', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) => _handlePostAction(value, post, index),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.bookmark_outline), SizedBox(width: 8), Text('Save Post')])),
                      const PopupMenuItem(value: 'hide', child: Row(children: [Icon(Icons.visibility_off), SizedBox(width: 8), Text('Hide Post')])),
                      const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined), SizedBox(width: 8), Text('Report Post')])),
                      if (post.author == 'You') const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 8), Text('Delete Post', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                post.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Content preview
              Text(
                post.content,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Tags
              Wrap(
                spacing: 8,
                children: post.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 12, color: Colors.blue[700])),
                )).toList(),
              ),
              const SizedBox(height: 12),
              // Vote and comment buttons
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            final origIndex = _posts.indexWhere((p) => p.id == post.id);
                            if (origIndex == -1) return;
                            if (_posts[origIndex].userVote == 1) {
                              _posts[origIndex].upvotes--;
                              _posts[origIndex].userVote = 0;
                            } else {
                              if (_posts[origIndex].userVote == -1) {
                                _posts[origIndex].downvotes--;
                              }
                              _posts[origIndex].upvotes++;
                              _posts[origIndex].userVote = 1;
                            }
                          }),
                          child: Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: post.userVote == 1 ? Colors.orange : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${post.score}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            final origIndex = _posts.indexWhere((p) => p.id == post.id);
                            if (origIndex == -1) return;
                            if (_posts[origIndex].userVote == -1) {
                              _posts[origIndex].downvotes--;
                              _posts[origIndex].userVote = 0;
                            } else {
                              if (_posts[origIndex].userVote == 1) {
                                _posts[origIndex].upvotes--;
                              }
                              _posts[origIndex].downvotes++;
                              _posts[origIndex].userVote = -1;
                            }
                          }),
                          child: Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: post.userVote == -1 ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('${post.comments} Comments', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _sharePost(post),
                    child: Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Analyzes post content for PCOS relevance using pure Dart AI verification
  /// Returns a map with 'approved' (bool) and 'reason' (String) keys
  Future<Map<String, dynamic>> _analyzePostRelevance(String title, String content) async {
    try {
      // Call pure Dart verifier service (no backend required)
      final result = await AIModerationService.verifyPcosContent(title, content);
      return {
        'approved': result.approved,
        'reason': result.reason,
        'score': result.relevanceScore,
        'terms_found': result.termsFound,
        'suggested_tags': result.suggestedTags,
      };
    } catch (e) {
      print('Moderation error: $e');
      return {
        'approved': false,
        'reason': 'Content verification failed. Please try again.',
        'score': 0.0,
        'terms_found': [],
        'suggested_tags': [],
      };
    }
  }

  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final List<String> selectedTags = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.pink[400]!, Colors.pink[600]!]),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create New Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('Share your experience with the community', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title input
                      Text('Title*', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind?',
                          prefixIcon: Icon(Icons.subject, color: Colors.pink[300]),
                          filled: true,
                          fillColor: Colors.pink[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[600]!, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      
                      // Content input
                      Text('Content*', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contentController,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts, questions, or experiences...',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Icon(Icons.description, color: Colors.pink[300]),
                          ),
                          filled: true,
                          fillColor: Colors.pink[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[600]!, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        maxLines: 8,
                        minLines: 6,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      
                      // Tags section
                      Row(
                        children: [
                          Icon(Icons.local_offer, color: Colors.pink[600], size: 18),
                          const SizedBox(width: 8),
                          Text('Tags (select up to 3):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                          const SizedBox(width: 4),
                          Text('${selectedTags.length}/3', style: TextStyle(fontSize: 11, color: Colors.pink[600], fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                            selected: isSelected,
                            onSelected: selectedTags.length < 3 || isSelected ? (selected) {
                              setDialogState(() {
                                if (selected && !selectedTags.contains(tag)) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            } : null,
                            backgroundColor: Colors.white,
                            selectedColor: Colors.pink[100],
                            side: BorderSide(color: isSelected ? Colors.pink[600]! : Colors.pink[200]!, width: 1.5),
                            checkmarkColor: Colors.pink[600],
                            avatar: isSelected ? Icon(Icons.check_circle, size: 16, color: Colors.pink[600]) : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Post'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                        onPressed: () async {
                          if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                            // Show loading dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogCtx) => const AlertDialog(
                                title: Text('Analyzing Post'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Checking for PCOS relevance...'),
                                  ],
                                ),
                              ),
                            );

                            // AI-based content moderation / verification
                            final moderation = await _analyzePostRelevance(
                              titleController.text,
                              contentController.text,
                            );

                            // Close loading dialog
                            Navigator.pop(context);

                            if (!(moderation['approved'] as bool)) {
                              // Show rejection dialog
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text('Post Rejected'),
                                  content: Text(moderation['reason'] as String),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('Edit Post'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('Dismiss'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // Merge suggested tags (from verifier) into selected tags up to 3
                              final suggested = (moderation['suggested_tags'] as List<dynamic>?)?.cast<String>() ?? [];
                              for (final tag in suggested) {
                                if (selectedTags.length >= 3) break;
                                if (!selectedTags.contains(tag)) selectedTags.add(tag);
                              }

                              // Determine tags to set on the post
                              List<String> tagsToUse;
                              if (selectedTags.isNotEmpty) {
                                tagsToUse = List<String>.from(selectedTags);
                              } else if (suggested.isNotEmpty) {
                                tagsToUse = suggested.length > 3 ? suggested.sublist(0, 3) : suggested;
                              } else {
                                tagsToUse = ['Discussion'];
                              }

                              // Post approved - add to forum
                              final newPost = ForumPost(
                                id: _posts.length + 1,
                                title: titleController.text,
                                content: contentController.text,
                                author: 'You',
                                postedTime: DateTime.now(),
                                upvotes: 1, // Self upvote
                                downvotes: 0,
                                comments: 0,
                                tags: tagsToUse,
                              );
                              setState(() => _posts.insert(0, newPost));
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(moderation['reason'] as String),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePostAction(String action, ForumPost post, int index) {
    switch (action) {
      case 'save':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post saved to your collection')),
        );
        break;
      case 'hide':
        setState(() {
          _posts.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post hidden'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                setState(() {
                  _posts.insert(index, post);
                });
              },
            ),
          ),
        );
        break;
      case 'report':
        _showReportDialog(post);
        break;
      case 'delete':
        _showDeleteConfirmation(post, index);
        break;
    }
  }

  void _showReportDialog(ForumPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Thank you for helping keep our community safe. Your report will be reviewed by our moderators.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post reported. Thank you for your feedback.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ForumPost post, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _posts.removeAt(index);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _sharePost(ForumPost post) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Share via Message'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening messages...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Share via Email'),
              onTap: () {
                Navigator.pop(ctx);
                _shareViaEmail(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareViaEmail(ForumPost post) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Check out this PCOS discussion: ${post.title}',
        'body': 'I thought you might find this discussion interesting:\n\n'
            '${post.title}\n\n'
            '${post.content}\n\n'
            'Posted by u/${post.author} on OvaCare Community Forum',
      },
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open email client on this device')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing via email: $e')),
        );
      }
    }
  }
}

class ForumPost {
  final int id;
  final String title;
  final String content;
  final String author;
  final DateTime postedTime;
  int upvotes;
  int downvotes;
  int userVote = 0; // -1 downvote, 0 neutral, 1 upvote
  final int comments;
  final List<String> tags;
  final List<ForumComment> replies;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.postedTime,
    required this.upvotes,
    required this.downvotes,
    required this.comments,
    required this.tags,
    this.replies = const [],
  });

  int get score => upvotes - downvotes;

  String get timeAgo {
    final diff = DateTime.now().difference(postedTime);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class ForumComment {
  final int id;
  final String author;
  final String content;
  final DateTime postedTime;
  int upvotes;
  int downvotes;
  final List<ForumComment> replies;

  ForumComment({
    required this.id,
    required this.author,
    required this.content,
    required this.postedTime,
    required this.upvotes,
    required this.downvotes,
    List<ForumComment>? replies,
  }) : replies = replies ?? [];

  int get score => upvotes - downvotes;

  String get timeAgo {
    final diff = DateTime.now().difference(postedTime);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class ForumPostPage extends StatefulWidget {
  final ForumPost post;

  const ForumPostPage({required this.post});

  @override
  State<ForumPostPage> createState() => _ForumPostPageState();
}

class _ForumPostPageState extends State<ForumPostPage> {
  late List<ForumComment> _comments;
  int _postUserVote = 0; // -1 downvote, 0 neutral, 1 upvote
  final Map<int, int> _commentVotes = {}; // commentId -> vote

  @override
  void initState() {
    super.initState();
    _comments = List<ForumComment>.from(widget.post.replies);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Original post
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.pink[100],
                        child: Text(widget.post.author[0].toUpperCase(), style: TextStyle(color: Colors.pink[700], fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('u/${widget.post.author}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('r/PCOS • ${widget.post.timeAgo}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(widget.post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  Text(widget.post.content, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 16),
                  // Vote and comment buttons
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                size: 18,
                                color: _postUserVote == 1 ? Colors.orange : Colors.grey,
                              ),
                              onPressed: () => _voteOnPost(1),
                            ),
                            Text('${widget.post.score}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                size: 18,
                                color: _postUserVote == -1 ? Colors.blue : Colors.grey,
                              ),
                              onPressed: () => _voteOnPost(-1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text('${_comments.length}'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200]),
                        onPressed: () {},
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => _sharePostFromDetail(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 2, color: Colors.grey[300]),
            // Comments section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_comments.length} Comments', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ..._comments.map((comment) => _buildCommentTile(comment)).toList(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Comment'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                    onPressed: () => _showAddCommentDialog(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(ForumComment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: Text(comment.author[0].toUpperCase(), style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('u/${comment.author}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text(comment.timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment.content, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _voteOnComment(comment.id, 1),
                          child: Icon(
                            Icons.arrow_upward,
                            size: 12,
                            color: _commentVotes[comment.id] == 1 ? Colors.orange : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('${comment.score}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _voteOnComment(comment.id, -1),
                          child: Icon(
                            Icons.arrow_downward,
                            size: 12,
                            color: _commentVotes[comment.id] == -1 ? Colors.blue : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _showReplyDialog(comment),
                          child: const Row(
                            children: [
                              Icon(Icons.reply, size: 12, color: Colors.grey),
                              SizedBox(width: 4),
                              Text('Reply', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 8),
              child: Column(
                children: comment.replies.map((reply) => _buildCommentTile(reply)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddCommentDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Comment', border: OutlineInputBorder()),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newComment = ForumComment(
                  id: _comments.length + 1,
                  author: 'You',
                  content: controller.text,
                  postedTime: DateTime.now(),
                  upvotes: 0,
                  downvotes: 0,
                );
                setState(() => _comments.insert(0, newComment));
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _voteOnPost(int vote) {
    setState(() {
      if (_postUserVote == vote) {
        // Remove vote
        if (vote == 1) {
          widget.post.upvotes--;
        } else {
          widget.post.downvotes--;
        }
        _postUserVote = 0;
      } else {
        // Change or add vote
        if (_postUserVote == 1) {
          widget.post.upvotes--;
        } else if (_postUserVote == -1) {
          widget.post.downvotes--;
        }

        if (vote == 1) {
          widget.post.upvotes++;
        } else {
          widget.post.downvotes++;
        }
        _postUserVote = vote;
      }
    });
  }

  void _voteOnComment(int commentId, int vote) {
    setState(() {
      final comment = _findCommentById(commentId);
      if (comment != null) {
        final currentVote = _commentVotes[commentId] ?? 0;
        
        if (currentVote == vote) {
          // Remove vote
          if (vote == 1) {
            comment.upvotes--;
          } else {
            comment.downvotes--;
          }
          _commentVotes[commentId] = 0;
        } else {
          // Change or add vote
          if (currentVote == 1) {
            comment.upvotes--;
          } else if (currentVote == -1) {
            comment.downvotes--;
          }

          if (vote == 1) {
            comment.upvotes++;
          } else {
            comment.downvotes++;
          }
          _commentVotes[commentId] = vote;
        }
      }
    });
  }

  ForumComment? _findCommentById(int commentId) {
    for (final comment in _comments) {
      if (comment.id == commentId) return comment;
      final found = _findCommentInReplies(comment.replies, commentId);
      if (found != null) return found;
    }
    return null;
  }

  ForumComment? _findCommentInReplies(List<ForumComment> replies, int commentId) {
    for (final reply in replies) {
      if (reply.id == commentId) return reply;
      final found = _findCommentInReplies(reply.replies, commentId);
      if (found != null) return found;
    }
    return null;
  }

  void _showReplyDialog(ForumComment parentComment) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reply to u/${parentComment.author}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                parentComment.content,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Your reply',
                border: OutlineInputBorder(),
                hintText: 'What are your thoughts?'
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newReply = ForumComment(
                  id: DateTime.now().millisecondsSinceEpoch,
                  author: 'You',
                  content: controller.text,
                  postedTime: DateTime.now(),
                  upvotes: 1, // Self upvote
                  downvotes: 0,
                );
                setState(() {
                  parentComment.replies.add(newReply);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reply posted successfully!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  void _sharePostFromDetail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Check out this PCOS discussion: ${widget.post.title}',
        'body': 'I thought you might find this discussion interesting:\n\n'
            '${widget.post.title}\n\n'
            '${widget.post.content}\n\n'
            'Posted by u/${widget.post.author} on OvaCare Community Forum',
      },
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open email client on this device')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing via email: $e')),
        );
      }
    }
  }
}

List<ForumPost> _generateSamplePosts() {
  return [
    ForumPost(
      id: 1,
      title: 'Just diagnosed with PCOS - feeling overwhelmed',
      content: 'I got diagnosed today and the doctor just listed all these symptoms. I have irregular periods and some weight gain. Anyone else felt like this at first? How did you manage?',
      author: 'SarahPCOS',
      postedTime: DateTime.now().subtract(const Duration(hours: 2)),
      upvotes: 234,
      downvotes: 5,
      comments: 18,
      tags: ['Support', 'NewDiagnosis'],
      replies: [
        ForumComment(
          id: 101,
          author: 'SupportiveSister',
          content: 'I felt exactly the same when I was diagnosed 2 years ago! It does get better. Take it one step at a time and don\'t overwhelm yourself with information all at once.',
          postedTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
          upvotes: 45,
          downvotes: 0,
        ),
        ForumComment(
          id: 102,
          author: 'PCOSWarrior',
          content: 'The diagnosis can be scary, but knowledge is power! Start with small lifestyle changes and find a good endocrinologist. You\'ve got this! 💪',
          postedTime: DateTime.now().subtract(const Duration(minutes: 45)),
          upvotes: 32,
          downvotes: 1,
          replies: [
            ForumComment(
              id: 103,
              author: 'SarahPCOS',
              content: 'Thank you so much! This community already feels so welcoming. I\'ll definitely look into finding an endocrinologist.',
              postedTime: DateTime.now().subtract(const Duration(minutes: 30)),
              upvotes: 12,
              downvotes: 0,
            ),
          ],
        ),
      ],
    ),
    ForumPost(
      id: 2,
      title: 'My inositol supplement routine - sharing what works for me',
      content: 'After trying different approaches, I found that taking myo-inositol with d-chiro-inositol (40:1 ratio) twice daily has really helped my cycle regularity. My cycles are now 28-30 days consistently!',
      author: 'HealthyJourney',
      postedTime: DateTime.now().subtract(const Duration(hours: 5)),
      upvotes: 156,
      downvotes: 3,
      comments: 24,
      tags: ['Supplements', 'Treatment'],
      replies: [
        ForumComment(
          id: 201,
          author: 'InositolFan',
          content: 'Which brand do you use? I\'ve been looking for a good quality supplement with the right ratio.',
          postedTime: DateTime.now().subtract(const Duration(hours: 3)),
          upvotes: 28,
          downvotes: 0,
        ),
        ForumComment(
          id: 202,
          author: 'SkepticalSarah',
          content: 'Did you notice any side effects when you first started? I\'m hesitant to try supplements without talking to my doctor first.',
          postedTime: DateTime.now().subtract(const Duration(hours: 2)),
          upvotes: 15,
          downvotes: 2,
        ),
      ],
    ),
    ForumPost(
      id: 3,
      title: 'Low-carb diet helped my PCOS symptoms significantly',
      content: 'I switched to a low-carb diet 3 months ago and my acne cleared up, energy improved, and my periods became more regular. Just wanted to share my experience!',
      author: 'FitnessFirst',
      postedTime: DateTime.now().subtract(const Duration(days: 1)),
      upvotes: 412,
      downvotes: 8,
      comments: 45,
      tags: ['Diet', 'Lifestyle'],
      replies: [
        ForumComment(
          id: 301,
          author: 'KetoQueen',
          content: 'Yes! Low-carb was a game changer for me too. The insulin resistance improvement was noticeable within weeks.',
          postedTime: DateTime.now().subtract(const Duration(hours: 18)),
          upvotes: 67,
          downvotes: 3,
        ),
        ForumComment(
          id: 302,
          author: 'ModerateApproach',
          content: 'I tried keto but found it too restrictive. I do better with just reducing refined carbs and focusing on whole foods.',
          postedTime: DateTime.now().subtract(const Duration(hours: 12)),
          upvotes: 34,
          downvotes: 5,
        ),
      ],
    ),
    ForumPost(
      id: 4,
      title: 'Exercise routine for PCOS - what works?',
      content: 'I\'ve read that exercise helps with insulin resistance. What types of exercise do you all do? I\'m looking to start something that won\'t be too stressful on my body.',
      author: 'ActiveLife',
      postedTime: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      upvotes: 98,
      downvotes: 2,
      comments: 32,
      tags: ['Exercise', 'Question'],
      replies: [
        ForumComment(
          id: 401,
          author: 'YogaLover',
          content: 'I love yoga and walking! Low-impact exercises work great for PCOS. I do 30 minutes of yoga daily and walk for 45 minutes.',
          postedTime: DateTime.now().subtract(const Duration(hours: 20)),
          upvotes: 42,
          downvotes: 1,
        ),
        ForumComment(
          id: 402,
          author: 'StrengthTrainer',
          content: 'Strength training 3x per week has been amazing for my insulin sensitivity. Start with bodyweight exercises if you\'re new to it.',
          postedTime: DateTime.now().subtract(const Duration(hours: 16)),
          upvotes: 38,
          downvotes: 0,
        ),
      ],
    ),
    ForumPost(
      id: 5,
      title: 'Hair loss with PCOS - anyone found a solution?',
      content: 'Dealing with hair loss and it\'s affecting my confidence. Has anyone found treatments that actually work? Considering seeing a dermatologist.',
      author: 'HairConcerns',
      postedTime: DateTime.now().subtract(const Duration(days: 2)),
      upvotes: 145,
      downvotes: 4,
      comments: 28,
      tags: ['Symptoms', 'Support'],
      replies: [
        ForumComment(
          id: 501,
          author: 'GrowthSuccess',
          content: 'Minoxidil and spironolactone helped me a lot! Also, addressing the root cause with metformin made a huge difference.',
          postedTime: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
          upvotes: 56,
          downvotes: 2,
        ),
        ForumComment(
          id: 502,
          author: 'NaturalHealing',
          content: 'I\'ve had success with saw palmetto, pumpkin seed oil, and scalp massage. Natural approaches take time but they work!',
          postedTime: DateTime.now().subtract(const Duration(hours: 30)),
          upvotes: 29,
          downvotes: 8,
        ),
      ],
    ),
  ];
}

// ============== DOCTOR DIRECTORY ==============

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialty = 'All';

  static const List<String> specialties = ['All', 'Gynecologist', 'Endocrinologist', 'Dermatologist', 'Nutritionist'];

  final List<Doctor> _doctors = [
    Doctor(
      id: 1,
      name: 'Dr. Maria Santos',
      specialty: 'Gynecologist',
      hospital: 'Florida Blanca District Hospital',
      rating: 4.9,
      reviews: 156,
      experience: '18 years',
      phone: '+63-45-625-1234',
      email: 'maria.santos@fbdh.gov.ph',
    ),
    Doctor(
      id: 2,
      name: 'Dr. Jose Reyes',
      specialty: 'Endocrinologist',
      hospital: 'Pampanga Medical Specialists',
      rating: 4.8,
      reviews: 142,
      experience: '15 years',
      phone: '+63-45-625-5678',
      email: 'jose.reyes@pampangamed.com',
    ),
    Doctor(
      id: 3,
      name: 'Dr. Carmen de Leon',
      specialty: 'Gynecologist',
      hospital: 'St. Catherine Medical Center',
      rating: 4.7,
      reviews: 98,
      experience: '12 years',
      phone: '+63-45-625-9012',
      email: 'carmen.deleon@stcatherine.ph',
    ),
    Doctor(
      id: 4,
      name: 'Dr. Ricardo Cruz',
      specialty: 'Dermatologist',
      hospital: 'Florida Blanca Skin Clinic',
      rating: 4.6,
      reviews: 87,
      experience: '10 years',
      phone: '+63-45-625-3456',
      email: 'ricardo.cruz@fbskin.com',
    ),
    Doctor(
      id: 5,
      name: 'Dr. Isabella Garcia',
      specialty: 'Nutritionist',
      hospital: 'Wellness Center Pampanga',
      rating: 4.8,
      reviews: 73,
      experience: '8 years',
      phone: '+63-45-625-7890',
      email: 'isabella.garcia@wellnesspampanga.ph',
    ),
    Doctor(
      id: 6,
      name: 'Dr. Antonio Mendoza',
      specialty: 'Endocrinologist',
      hospital: 'Angels University Foundation Medical Center',
      rating: 4.9,
      reviews: 201,
      experience: '22 years',
      phone: '+63-45-625-2468',
      email: 'antonio.mendoza@auf.edu.ph',
    ),
    Doctor(
      id: 7,
      name: 'Dr. Luz Fernandez',
      specialty: 'Gynecologist',
      hospital: 'Holy Angel Medical Center',
      rating: 4.7,
      reviews: 134,
      experience: '16 years',
      phone: '+63-45-625-1357',
      email: 'luz.fernandez@hamc.ph',
    ),
    Doctor(
      id: 8,
      name: 'Dr. Miguel Villanueva',
      specialty: 'Nutritionist',
      hospital: 'Pampanga Nutrition Hub',
      rating: 4.5,
      reviews: 65,
      experience: '7 years',
      phone: '+63-45-625-8024',
      email: 'miguel.villanueva@pampanganutrition.com',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _doctors.where((d) {
      final matchesSearch = d.name.toLowerCase().contains(_searchController.text.toLowerCase()) || d.hospital.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesSpecialty = _selectedSpecialty == 'All' || d.specialty == _selectedSpecialty;
      return matchesSearch && matchesSpecialty;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search doctors or hospitals...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: specialties.map((specialty) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(specialty),
                    selected: _selectedSpecialty == specialty,
                    onSelected: (_) => setState(() => _selectedSpecialty = specialty),
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildDoctorCard(filtered[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal[100],
                  child: Icon(Icons.person_outline, color: Colors.teal[700], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(doctor.specialty, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      Text(doctor.hospital, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${doctor.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('(${doctor.reviews} reviews)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.work_outline, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(doctor.experience, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    onPressed: () => _makePhoneCall(doctor.phone),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.email),
                    label: const Text('Email'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: () => _sendEmail(doctor.email),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to make phone calls
  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        // Show a snackbar if the device cannot make calls
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot make phone calls on this device. Number: $phoneNumber'),
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  // In a real app, you would copy to clipboard here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone number copied to clipboard')),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making phone call: $e')),
        );
      }
    }
  }

  // Helper method to send emails
  void _sendEmail(String emailAddress) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      queryParameters: {
        'subject': 'PCOS Consultation Inquiry from OvaCare App',
        'body': 'Hello Dr.,\n\nI would like to schedule a consultation regarding PCOS management. I am using the OvaCare app to track my symptoms and health data.\n\nThank you for your time.\n\nBest regards,',
      },
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // Show a snackbar if the device cannot send emails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot send emails on this device. Email: $emailAddress'),
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  // In a real app, you would copy to clipboard here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email address copied to clipboard')),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending email: $e')),
        );
      }
    }
  }
}

class Doctor {
  final int id;
  final String name;
  final String specialty;
  final String hospital;
  final double rating;
  final int reviews;
  final String experience;
  final String phone;
  final String email;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.rating,
    required this.reviews,
    required this.experience,
    required this.phone,
    required this.email,
  });
}

// ============== DATA REPORTING ==============

class DataReportingScreen extends StatelessWidget {
  const DataReportingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text('Generate and Export', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink[700])),
          const SizedBox(height: 16),
          _buildReportCard(
            title: 'Monthly Health Summary',
            description: 'Get a comprehensive overview of your health metrics for the month.',
            icon: Icons.calendar_month,
            onTap: () => _showReportDialog(context, 'Monthly Health Summary'),
          ),
          _buildReportCard(
            title: 'Cycle Analysis Report',
            description: 'Detailed analysis of your menstrual cycles and predictions.',
            icon: Icons.auto_graph,
            onTap: () => _showReportDialog(context, 'Cycle Analysis Report'),
          ),
          _buildReportCard(
            title: 'Symptom Tracking Report',
            description: 'Summary of all symptoms tracked and patterns identified.',
            icon: Icons.trending_up,
            onTap: () => _showReportDialog(context, 'Symptom Tracking Report'),
          ),
          _buildReportCard(
            title: 'Risk Assessment Report',
            description: 'Your PCOS risk assessment and recommendations.',
            icon: Icons.warning_outlined,
            onTap: () => _showReportDialog(context, 'Risk Assessment Report'),
          ),
          const SizedBox(height: 24),
          Text('Export Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink[700])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text('Download as PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF download would be initiated here')),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share with Doctor'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share dialog would open here')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Function() onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Colors.pink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String reportType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reportType),
        content: Text('Your $reportType has been generated and is ready to download or share.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report prepared for download')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

// ============== LIFESTYLE & WELLNESS ==============

class LifestyleWellnessScreen extends StatelessWidget {
  const LifestyleWellnessScreen({super.key});

  static const List<Map<String, dynamic>> recommendations = [
    {
      'emoji': '🧘‍♀️',
      'title': 'Stress Management',
      'items': [
        'Practice yoga or meditation daily',
        'Take short breaks throughout the day',
        'Journaling to process emotions',
        'Breathing exercises (5-10 minutes)',
      ]
    },
    {
      'emoji': '🏃‍♀️',
      'title': 'Physical Activity',
      'items': [
        'Aim for 150 minutes of moderate exercise weekly',
        'Mix cardio and strength training',
        'Walk for 30 minutes most days',
        'Try pilates or low-impact activities',
      ]
    },
    {
      'emoji': '🥗',
      'title': 'Nutrition',
      'items': [
        'Eat whole grains and lean proteins',
        'Include plenty of fiber and vegetables',
        'Reduce processed foods and added sugars',
        'Stay hydrated (8 glasses of water daily)',
      ]
    },
    {
      'emoji': '😴',
      'title': 'Sleep & Recovery',
      'items': [
        'Aim for 7-9 hours of sleep',
        'Maintain a consistent sleep schedule',
        'Create a relaxing bedtime routine',
        'Avoid screens 1 hour before bed',
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifestyle & Wellness')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: recommendations.map((rec) => Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rec['emoji'] as String, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rec['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...(rec['items'] as List).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item as String, style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}
