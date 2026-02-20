import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_moderation_service.dart';
import 'dialog_helper.dart';

SupabaseClient? _getSupabaseClientOrNull() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

String _resolveAuthorName(User? user) {
  if (user == null) return 'Anonymous';
  return user.userMetadata?['username'] as String? ?? 
         user.email?.split('@').first ?? 
         'User${user.id.substring(0, 6)}';
}

// ============== COMMUNITY FORUM (Reddit-like) ==============

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({Key? key}) : super(key: key);

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> {
  List<ForumPost> _posts = [];
  bool _isLoading = true;
  String _sortBy = 'auto';
  bool _summaryExpanded = true;
  final Map<String, String> _sortLabels = {
    'hot': 'Hot',
    'auto': 'Auto',
    'new': 'New',
    'top': 'Top',
    'relevant': 'Relevant',
  };
  final Map<int, int> _userPostVotes = {}; // Already exists

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    
    try {
      final client = _getSupabaseClientOrNull();
      if (client == null) {
        setState(() {
          _posts = _generateSamplePosts();
          _isLoading = false;
        });
        return;
      }

      final user = client.auth.currentUser;
      
      // Load posts
      final rows = await client
          .from('forum_posts')
          .select()
          .order('posted_at', ascending: false);

      // IMPORTANT: Load user votes if signed in
      if (user != null) {
        final votes = await client
            .from('user_votes')
            .select('post_id, vote_type')
            .eq('user_id', user.id)
            .isFilter('comment_id', null); // Only post votes, not comment votes

        // Clear and rebuild the votes map
        _userPostVotes.clear();
        for (final vote in votes) {
          _userPostVotes[vote['post_id'] as int] = vote['vote_type'] as int;
        }
      } else {
        _userPostVotes.clear();
      }

      final posts = rows.map((row) => ForumPost(
        id: row['id'] as int,
        userId: row['user_id'] as String?,
        title: row['title'] as String,
        content: row['content'] as String,
        author: row['author']?.toString() ?? 'Anonymous',
        postedTime: DateTime.parse(row['posted_at'] as String).toLocal(),
        upvotes: row['upvotes'] as int? ?? 0,
        downvotes: row['downvotes'] as int? ?? 0,
        comments: row['comments_count'] as int? ?? 0,
        tags: (row['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        relevanceScore: row['relevance_score'] as double?,
        primaryTopic: row['primary_topic'] as String?,
        detectedPcosTerms: ((row['detected_terms'] as List<dynamic>?) ?? (row['detected_terms'] as List<dynamic>?))?.map((e) => e.toString()).toList(),
        isPcosRelevant: row['is_pcos_relevant'] as bool? ?? true,
      )).toList();

      setState(() {
        _posts = posts;
        _isLoading = false;
        // Automatically apply sorting that prefers recent and high-engagement posts
        _applyAutomaticSorting();
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _posts = _generateSamplePosts();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Community Forum',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _sortLabels[_sortBy] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.pink, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.pink),
        actions: [
          PopupMenuButton<String>(
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() => _sortBy = value);
              _sortPosts();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'hot', child: Text('Hot')),
              const PopupMenuItem(value: 'new', child: Text('New')),
              const PopupMenuItem(value: 'top', child: Text('Top')),
              const PopupMenuItem(value: 'relevant', child: Text('Relevant (AI)')),
            ],
            icon: const Icon(Icons.sort, color: Colors.pink),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: _posts.isEmpty
                  ? const Center(child: Text('No posts yet. Be the first to share!'))
                  : ListView.builder(
                      itemCount: _posts.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildDailySummary(_posts);
                        }
                        return _buildPostCard(_posts[index - 1], index - 1);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.pink[400],
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _sortPosts() {
    setState(() {
      if (_sortBy == 'auto') {
        _applyAutomaticSorting();
        return;
      }
      if (_sortBy == 'hot') {
        // Hot = score + recency (score * 1000000 + recency in ms)
        _posts.sort((a, b) {
          final now = DateTime.now();
          int aHot = a.score * 1000000 - now.difference(a.postedTime).inMilliseconds;
          int bHot = b.score * 1000000 - now.difference(b.postedTime).inMilliseconds;
          return bHot.compareTo(aHot);
        });
      } else if (_sortBy == 'new') {
        _posts.sort((a, b) => b.postedTime.compareTo(a.postedTime));
      } else if (_sortBy == 'top') {
        // Top = upvotes + relevanceScore (if available)
        _posts.sort((a, b) {
          double aTop = a.upvotes.toDouble() + (a.relevanceScore ?? 0.0);
          double bTop = b.upvotes.toDouble() + (b.relevanceScore ?? 0.0);
          return bTop.compareTo(aTop);
        });
      } else if (_sortBy == 'relevant') {
        // Relevant = AI relevanceScore (fallback to 0)
        _posts.sort((a, b) => (b.relevanceScore ?? 0.0).compareTo(a.relevanceScore ?? 0.0));
      }
    });
  }

  void _applyAutomaticSorting() {
    // Score = engagement component + recency component
    final now = DateTime.now();
    _posts.sort((a, b) {
      double engagementA = a.upvotes.toDouble() + (a.comments.toDouble() * 0.8) + (a.score);
      double engagementB = b.upvotes.toDouble() + (b.comments.toDouble() * 0.8) + (b.score);

      // Recency factor: newer posts get boosted (range 0..1 for 0..48 hours)
      final ageA = now.difference(a.postedTime).inHours.toDouble();
      final ageB = now.difference(b.postedTime).inHours.toDouble();
      double recencyA = (48.0 - ageA) / 48.0; if (recencyA < 0) recencyA = 0; if (recencyA > 1) recencyA = 1;
      double recencyB = (48.0 - ageB) / 48.0; if (recencyB < 0) recencyB = 0; if (recencyB > 1) recencyB = 1;

      // Combine: weight engagement higher but keep recency significant
      final scoreA = (engagementA * 2.0) + (recencyA * 20.0);
      final scoreB = (engagementB * 2.0) + (recencyB * 20.0);

      return scoreB.compareTo(scoreA);
    });
  }

  Widget _buildDailySummary(List<ForumPost> posts) {
    final today = DateTime.now();
    final todayList = posts.where((p) =>
      p.postedTime.year == today.year &&
      p.postedTime.month == today.month &&
      p.postedTime.day == today.day
    ).toList();

    final todayPosts = todayList.length;
    final totalComments = todayList.fold<int>(0, (sum, post) => sum + post.comments);
    final totalUpvotes = todayList.fold<int>(0, (sum, post) => sum + post.upvotes);

    // Aggregate top tags, topics and detected terms for today's posts
    final Map<String, int> tagCounts = {};
    final Map<String, int> topicCounts = {};
    final Map<String, int> termCounts = {};

    for (final p in todayList) {
      final weight = 1 + (p.upvotes.toDouble() * 0.2) + (p.comments.toDouble() * 0.15);
      for (final t in p.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + weight.round();
      }
      final topic = p.primaryTopic ?? 'general';
      topicCounts[topic] = (topicCounts[topic] ?? 0) + weight.round();
      for (final term in p.detectedPcosTerms ?? []) {
        termCounts[term] = (termCounts[term] ?? 0) + weight.round();
      }
    }

    List<String> topKeys(Map<String,int> counts, [int n = 3]) {
      final entries = counts.entries.toList();
      entries.sort((a,b) => b.value.compareTo(a.value));
      return entries.take(n).map((e) => e.key).toList();
    }

    final topTags = topKeys(tagCounts);
    final topTopics = topKeys(topicCounts);
    final topTerms = topKeys(termCounts);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Daily summary', style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                icon: Icon(_summaryExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.pink),
                onPressed: () => setState(() => _summaryExpanded = !_summaryExpanded),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(Icons.post_add, todayPosts.toString(), 'Posts', Colors.pink),
                    _buildStatCard(Icons.chat_bubble, totalComments.toString(), 'Comments', Colors.pink),
                    _buildStatCard(Icons.arrow_upward, totalUpvotes.toString(), 'Upvotes', Colors.pink),
                  ],
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (ctx) {
                    if (todayPosts == 0) {
                      return const Text('No posts today.', style: TextStyle(color: Colors.black54));
                    }

                    final tagsText = topTags.isNotEmpty ? topTags.join(', ') : 'none';
                    final topicsText = topTopics.isNotEmpty ? topTopics.join(', ') : 'general';
                    final termsText = topTerms.isNotEmpty ? topTerms.join(', ') : '';

                    final sentence = StringBuffer();
                    sentence.write('Today there were $todayPosts post${todayPosts == 1 ? '' : 's'}, $totalComments comment${totalComments == 1 ? '' : 's'} and $totalUpvotes upvote${totalUpvotes == 1 ? '' : 's'}. ');
                    sentence.write('Top tags: $tagsText. ');
                    sentence.write('Top topics: $topicsText.');
                    if (termsText.isNotEmpty) sentence.write(' Keywords: $termsText.');

                    return Text(sentence.toString(), style: const TextStyle(fontSize: 13, color: Colors.black87));
                  },
                ),
              ],
            ),
            secondChild: GestureDetector(
              onTap: () => setState(() => _summaryExpanded = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('$todayPosts post${todayPosts == 1 ? '' : 's'} today — tap to show summary', style: const TextStyle(color: Colors.black54)),
              ),
            ),
            crossFadeState: _summaryExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, MaterialColor color) {
    return Column(
      children: [
        Icon(icon, color: Colors.pink[400], size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pink[400])),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.pink[300], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPostCard(ForumPost post, int index) {
    final userVote = _userPostVotes[post.id] ?? 0; // Get current user's vote
    
    return InkWell(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumPostPage(
              post: post,
              userVote: userVote,
            ),
          ),
        );
        if (updated != null && updated is ForumPost) {
          setState(() {
            _posts[index] = updated;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.pink[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.pink[50],
                  child: Text(
                    post.author[0].toUpperCase(),
                    style: const TextStyle(color: Colors.pink, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('u/${post.author}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.pink)),
                      Text(post.timeAgo, style: const TextStyle(fontSize: 10, color: Colors.pink)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) => _handlePostAction(action, post, index),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                    if (post.userId == _getSupabaseClientOrNull()?.auth.currentUser?.id)
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.pink),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 6),
            Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: post.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    border: Border.all(color: Colors.pink[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.pink)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _voteOnPostFromList(post, 1),
                  child: Icon(userVote == 1 ? Icons.arrow_upward : Icons.arrow_upward_outlined, size: 18, color: userVote == 1 ? Colors.pink : Colors.pink[200]),
                ),
                const SizedBox(width: 4),
                Text('${post.score}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: userVote == 1 ? Colors.pink : (userVote == -1 ? Colors.pink[200] : Colors.black54))),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _voteOnPostFromList(post, -1),
                  child: Icon(userVote == -1 ? Icons.arrow_downward : Icons.arrow_downward_outlined, size: 18, color: userVote == -1 ? Colors.pink[200] : Colors.pink[100]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline, size: 16, color: Colors.pink[200]),
                const SizedBox(width: 4),
                Text('${post.comments}', style: const TextStyle(fontSize: 12, color: Colors.pink)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _sharePost(post),
                  child: const Icon(Icons.share_outlined, size: 16, color: Colors.pink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _analyzePostRelevance(String title, String content) async {
    try {
      final service = AIModerationService();
      final result = await service.analyzePcosRelevance(title, content);
      return result;
    } catch (e) {
      print('Error analyzing post relevance: $e');
      return {
        'approved': true,
        'relevance_score': 0.0,
        'primary_topic': 'general',
        'detected_terms': [],
        'is_pcos_relevant': true,
      };
    }
  }

  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    List<String> selectedTags = [];
    List<String> aiSuggestedTags = [];
    bool isSubmitting = false;
    bool showSuggestions = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.create, color: Colors.pink, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Create New Post', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLength: 300,
                  onChanged: (_) async {
                    // Suggest tags as user types
                    final analysis = await _analyzePostRelevance(titleController.text, contentController.text);
                    setDialogState(() {
                      aiSuggestedTags = (analysis['suggested_tags'] as List?)?.cast<String>() ?? [];
                      showSuggestions = aiSuggestedTags.isNotEmpty;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 5,
                  maxLength: 10000,
                  onChanged: (_) async {
                    // Suggest tags as user types
                    final analysis = await _analyzePostRelevance(titleController.text, contentController.text);
                    setDialogState(() {
                      aiSuggestedTags = (analysis['suggested_tags'] as List?)?.cast<String>() ?? [];
                      showSuggestions = aiSuggestedTags.isNotEmpty;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Tags (select up to 3)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
                    const Spacer(),
                    Text('${selectedTags.length}/3', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ...selectedTags.map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: Colors.pink[50],
                          labelStyle: const TextStyle(color: Colors.pink),
                          deleteIcon: const Icon(Icons.close, size: 16, color: Colors.pink),
                          onDeleted: () {
                            setDialogState(() {
                              selectedTags.remove(tag);
                            });
                          },
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    // Static tag options shown as selectable chips
                    ...[ 'PCOS Support', 'Symptoms', 'Treatment', 'Lifestyle', 'Experience', 'Discussion', 'Advice', 'Fertility', 'Exercise', 'Diet', 'Mental Health', 'Success', 'Story', 'Journey', 'Tips', 'Support', 'Doctor', 'Medication', 'Wellness', 'Sleep', 'Weight', 'Nutrition', 'Community' ]
                      .map((tag) => FilterChip(
                              label: Text(tag),
                              selected: selectedTags.contains(tag),
                              selectedColor: Colors.pink[100],
                              checkmarkColor: Colors.pink,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    if (!selectedTags.contains(tag) && selectedTags.length < 3) {
                                      selectedTags.add(tag);
                                    } else if (selectedTags.length >= 3) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can select up to 3 tags')));
                                    }
                                  } else {
                                    selectedTags.remove(tag);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ],
                ),
                if (showSuggestions && aiSuggestedTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('AI Suggestions:', style: TextStyle(fontSize: 12, color: Colors.pink)),
                  Wrap(
                    spacing: 6,
                    children: aiSuggestedTags.map((tag) => ActionChip(
                      label: Text(tag),
                      backgroundColor: Colors.pink[100],
                      labelStyle: const TextStyle(color: Colors.pink),
                      onPressed: () {
                          if (!selectedTags.contains(tag) && selectedTags.length < 3) {
                            setDialogState(() {
                              selectedTags.add(tag);
                            });
                          } else if (selectedTags.length >= 3) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can select up to 3 tags')));
                          }
                      },
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting ? null : () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                final tags = selectedTags;

                if (title.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                setDialogState(() => isSubmitting = true);

                try {
                  final client = _getSupabaseClientOrNull();
                  if (client == null) throw Exception('Not connected to database');

                  final user = client.auth.currentUser;
                  if (user == null) throw Exception('Please sign in to post');

                  // Analyze relevance
                  final analysis = await _analyzePostRelevance(title, content);

                  if (!analysis['approved']) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(analysis['message'] ?? 'Post not PCOS-relevant'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  // Insert post
                  final inserted = await client.from('forum_posts').insert({
                    'user_id': user.id,
                    'author': _resolveAuthorName(user),
                    'title': title,
                    'content': content,
                    'upvotes': 0,
                    'downvotes': 0,
                    'comments_count': 0,
                    'tags': tags,
                    'relevance_score': analysis['relevance_score'],
                    'primary_topic': analysis['primary_topic'],
                    // Store detected terms
                    'detected_terms': analysis['detected_terms'] ?? [],
                    'is_pcos_relevant': analysis['is_pcos_relevant'],
                  }).select().single();

                  final newPost = ForumPost(
                    id: inserted['id'] as int,
                    userId: inserted['user_id'] as String,
                    title: inserted['title'] as String,
                    content: inserted['content'] as String,
                    author: inserted['author'] as String,
                    postedTime: DateTime.parse(inserted['posted_at'] as String).toLocal(),
                    upvotes: 0,
                    downvotes: 0,
                    comments: 0,
                    tags: tags,
                    relevanceScore: analysis['relevance_score'] as double?,
                    primaryTopic: analysis['primary_topic'] as String?,
                    detectedPcosTerms: ((analysis['detected_terms'] as List?) ?? (analysis['detected_terms'] as List?))?.cast<String>(),
                    isPcosRelevant: analysis['is_pcos_relevant'] as bool? ?? true,
                  );

                  Navigator.pop(context);
                  setState(() {
                    _posts.insert(0, newPost);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create post: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('Post'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePostAction(String action, ForumPost post, int index) {
    switch (action) {
      case 'share':
        _sharePost(post);
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
    DialogHelper.showConfirmationDialog(
      context: context,
      title: 'Report Post',
      message: 'Are you sure you want to report this post for violating community guidelines?',
      confirmText: 'Report',
      cancelText: 'Cancel',
      isDangerous: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          final client = _getSupabaseClientOrNull();
          if (client != null) {
            // Get current user for reporting
            final currentUser = client.auth.currentUser;
            if (currentUser != null) {
              // Store content report in database
              // Note: You'll need to create a content_reports table in Supabase
              // For now, we'll just show a success message
              await Future.delayed(const Duration(milliseconds: 500)); // Simulate async operation
              print('✅ Post reported by user: ${currentUser.id}');
            }
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post reported. Thank you for keeping our community safe.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to report post: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  void _showDeleteConfirmation(ForumPost post, int index) {
    DialogHelper.showConfirmationDialog(
      context: context,
      title: 'Delete Post',
      message: 'Are you sure you want to delete this post? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          final client = _getSupabaseClientOrNull();
          if (client != null) {
            await client.from('forum_posts').delete().eq('id', post.id);
          }

          setState(() {
            _posts.removeAt(index);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete post: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _voteOnPostFromList(ForumPost post, int vote) async {
    final client = _getSupabaseClientOrNull();
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null) return;

    final currentVote = _userPostVotes[post.id] ?? 0;

    if (currentVote == vote) {
      // Remove vote
      await client
        .from('user_votes')
        .delete()
        .eq('user_id', user.id)
        .eq('post_id', post.id)
        .isFilter('comment_id', null);
    } else if (currentVote == 0) {
      // Insert new vote
      await client.from('user_votes').insert({
        'user_id': user.id,
        'post_id': post.id,
        'vote_type': vote,
        'comment_id': null, // <-- add this!
      });
    } else {
      // Update existing vote
      await client
        .from('user_votes')
        .update({'vote_type': vote})
        .eq('user_id', user.id)
        .eq('post_id', post.id)
        .isFilter('comment_id', null);
    }
  }

  void _sharePost(ForumPost post) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Share via Email'),
              onTap: () {
                Navigator.pop(ctx);
                _shareViaEmail(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
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
  final String? userId;
  final String title;
  final String content;
  final String author;
  final DateTime postedTime;
  int upvotes;
  int downvotes;
  int userVote = 0;
  int comments;
  final List<String> tags;
  final List<ForumComment> replies;
  
  final double? relevanceScore;
  final String? primaryTopic;
  final List<String>? detectedPcosTerms;
  final bool isPcosRelevant;

  ForumPost({
    required this.id,
    this.userId,
    required this.title,
    required this.content,
    required this.author,
    required this.postedTime,
    required this.upvotes,
    required this.downvotes,
    required this.comments,
    required this.tags,
    this.replies = const [],
    this.relevanceScore,
    this.primaryTopic,
    this.detectedPcosTerms,
    this.isPcosRelevant = true,
  });

  int get score => upvotes - downvotes;

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(postedTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${postedTime.month}/${postedTime.day}/${postedTime.year}';
    }
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
    final now = DateTime.now();
    final diff = now.difference(postedTime);
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${postedTime.month}/${postedTime.day}/${postedTime.year}';
    }
  }
}

class ForumPostPage extends StatefulWidget {
  final ForumPost post;
  final int userVote; // Add this parameter

  const ForumPostPage({
    Key? key, 
    required this.post,
    this.userVote = 0, // Default to no vote
  }) : super(key: key);

  @override
  State<ForumPostPage> createState() => _ForumPostPageState();
}

class _ForumPostPageState extends State<ForumPostPage> {
  late List<ForumComment> _comments;
  late int _userPostVote; // Changed from int to late int
  Map<int, int> _userCommentVotes = {};

  @override
  void initState() {
    super.initState();
    _comments = List<ForumComment>.from(widget.post.replies);
    _userPostVote = widget.userVote; // Initialize from parameter
    _loadComments();
    _loadUserVotes();
  }

  Future<void> _loadUserVotes() async {
    final client = _getSupabaseClientOrNull();
    if (client == null) return;
    
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      // Load post vote
      final postVotes = await client
          .from('user_votes')
          .select('vote_type')
          .eq('user_id', user.id)
          .eq('post_id', widget.post.id)
          .isFilter('comment_id', null);
      
      // Load comment votes
      final commentVotes = await client
          .from('user_votes')
          .select('comment_id, vote_type')
          .eq('user_id', user.id)
          .not('comment_id', 'is', null);

      final Map<int, int> votes = {};
      for (final row in commentVotes) {
        final commentId = row['comment_id'] as int?;
        final voteType = row['vote_type'] as int?;
        if (commentId != null && voteType != null) {
          votes[commentId] = voteType;
        }
      }

      if (mounted) {
        setState(() {
          _userPostVote = postVotes.isNotEmpty ? (postVotes.first['vote_type'] as int? ?? 0) : 0;
          _userCommentVotes = votes;
        });
      }
    } catch (e) {
      print('Failed to load user votes: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final client = _getSupabaseClientOrNull();
      if (client == null) return;

      final rows = await client
          .from('forum_comments')
          .select()
          .eq('post_id', widget.post.id)
          .order('posted_at', ascending: false);

      final Map<int, ForumComment> commentMap = {};
      final List<ForumComment> topLevel = [];

      for (final row in rows) {
        final comment = _mapRowToComment(row);
        commentMap[comment.id] = comment;
      }

      for (final row in rows) {
        final commentId = row['id'] as int;
        final parentId = row['parent_id'] as int?;
        final comment = commentMap[commentId]!;

        if (parentId == null) {
          topLevel.add(comment);
        } else {
          final parent = commentMap[parentId];
          if (parent != null) {
            parent.replies.add(comment);
          }
        }
      }

      setState(() {
        _comments = topLevel;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    }
  }

  ForumComment _mapRowToComment(Map<String, dynamic> row) {
    return ForumComment(
      id: row['id'] as int,
      author: row['author']?.toString() ?? 'Unknown',
      content: row['content'] as String,
      postedTime: DateTime.parse(row['posted_at'] as String).toLocal(),
      upvotes: row['upvotes'] as int? ?? 0,
      downvotes: row['downvotes'] as int? ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, widget.post);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Post'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, widget.post),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
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
                          child: Text(
                            widget.post.author[0].toUpperCase(),
                            style: TextStyle(color: Colors.pink[700], fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'u/${widget.post.author}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                'r/PCOS • ${widget.post.timeAgo}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.post.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.post.content,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: _userPostVote != 0 
                                ? (_userPostVote == 1 ? Colors.orange[50] : Colors.blue[50]) 
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: _userPostVote != 0 ? Border.all(
                              color: _userPostVote == 1 ? Colors.orange : Colors.blue,
                              width: 1.5,
                            ) : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _userPostVote == 1 ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                                  size: 20,
                                  color: _userPostVote == 1 ? Colors.orange[700] : Colors.grey[600],
                                ),
                                onPressed: () => _voteOnPost(1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.post.score}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _userPostVote == 1 
                                      ? Colors.orange[700] 
                                      : (_userPostVote == -1 ? Colors.blue[700] : Colors.grey[800]),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  _userPostVote == -1 ? Icons.arrow_downward : Icons.arrow_downward_outlined,
                                  size: 20,
                                  color: _userPostVote == -1 ? Colors.blue[700] : Colors.grey[600],
                                ),
                                onPressed: () => _voteOnPost(-1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 18),
                              const SizedBox(width: 6),
                              Text('${_comments.length}'),
                            ],
                          ),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_comments.length} Comments',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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
      ),
    );
  }

  Widget _buildCommentTile(ForumComment comment) {
    final userVote = _userCommentVotes[comment.id] ?? 0;
    
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
                child: Text(
                  comment.author[0].toUpperCase(),
                  style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'u/${comment.author}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.timeAgo,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _voteOnComment(comment.id, 1),
                          child: Icon(
                            userVote == 1 ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                            size: 14,
                            color: userVote == 1 ? Colors.orange[700] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.score}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: userVote != 0 ? FontWeight.bold : FontWeight.normal,
                            color: userVote == 1 
                                ? Colors.orange[700] 
                                : (userVote == -1 ? Colors.blue[700] : Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _voteOnComment(comment.id, -1),
                          child: Icon(
                            userVote == -1 ? Icons.arrow_downward : Icons.arrow_downward_outlined,
                            size: 14,
                            color: userVote == -1 ? Colors.blue[700] : Colors.grey[600],
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
    DialogHelper.showInputDialog(
      context: context,
      title: 'Add Comment',
      subtitle: 'Share your thoughts with the community',
      hintText: 'Write your comment here...',
      confirmText: 'Post',
      cancelText: 'Cancel',
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: Colors.pink[400],
      maxLines: 4,
    ).then((text) async {
      if (text != null && text.isNotEmpty) {
        try {
          final client = _getSupabaseClientOrNull();
          if (client == null) throw Exception('Supabase is not initialized.');
          
          final user = client.auth.currentUser;
          if (user == null) throw Exception('Please sign in to comment.');

          final inserted = await client.from('forum_comments').insert({
            'post_id': widget.post.id,
            'user_id': user.id,
            'author': _resolveAuthorName(user),
            'content': text,
            'upvotes': 0,
            'downvotes': 0,
          }).select().single();

          final newComment = _mapRowToComment(inserted);
          setState(() {
            _comments.insert(0, newComment);
            widget.post.comments++;
          });

          try {
            await client.from('forum_posts').update({
              'comments_count': widget.post.comments,
            }).eq('id', widget.post.id);
          } catch (_) {}
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Reply posted successfully!'),
                  ],
                ),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to post comment: $e'),
                backgroundColor: Colors.red[600],
              ),
            );
          }
        }
      }
    });
  }

  void _voteOnPost(int vote) async {
    final client = _getSupabaseClientOrNull();
    if (client == null) return;
    
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to vote')),
        );
      }
      return;
    }

    final oldUpvotes = widget.post.upvotes;
    final oldDownvotes = widget.post.downvotes;
    final oldVote = _userPostVote;

    if (_userPostVote == vote) {
      setState(() {
        if (vote == 1) {
          widget.post.upvotes--;
        } else {
          widget.post.downvotes--;
        }
        _userPostVote = 0;
      });

      try {
        await client
            .from('user_votes')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', widget.post.id);

        await client.from('forum_posts').update({
          'upvotes': widget.post.upvotes,
          'downvotes': widget.post.downvotes,
        }).eq('id', widget.post.id);
      } catch (e) {
        setState(() {
          widget.post.upvotes = oldUpvotes;
          widget.post.downvotes = oldDownvotes;
          _userPostVote = oldVote;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove vote: $e')),
          );
        }
      }
      return;
    }

    setState(() {
      if (_userPostVote == 1) {
        widget.post.upvotes--;
      } else if (_userPostVote == -1) {
        widget.post.downvotes--;
      }

      if (vote == 1) {
        widget.post.upvotes++;
      } else {
        widget.post.downvotes++;
      }

      _userPostVote = vote;
    });

    try {
      if (oldVote == 0) {
        await client.from('user_votes').insert({
          'user_id': user.id,
          'post_id': widget.post.id,
          'vote_type': vote,
          'comment_id': null,
        });
      } else {
        await client
            .from('user_votes')
            .update({'vote_type': vote})
            .eq('user_id', user.id)
            .eq('post_id', widget.post.id)
            .isFilter('comment_id', null);
      }

      await client.from('forum_posts').update({
        'upvotes': widget.post.upvotes,
        'downvotes': widget.post.downvotes,
      }).eq('id', widget.post.id);
    } catch (e) {
      setState(() {
        widget.post.upvotes = oldUpvotes;
        widget.post.downvotes = oldDownvotes;
        _userPostVote = oldVote;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _voteOnComment(int commentId, int vote) async {
    final client = _getSupabaseClientOrNull();
    if (client == null) return;
    
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to vote')),
        );
      }
      return;
    }

    final comment = _findCommentById(commentId);
    if (comment == null) return;

    final currentVote = _userCommentVotes[commentId] ?? 0;
    final oldUpvotes = comment.upvotes;
    final oldDownvotes = comment.downvotes;

    if (currentVote == vote) {
      setState(() {
        if (vote == 1) {
          comment.upvotes--;
        } else {
          comment.downvotes--;
        }
        _userCommentVotes.remove(commentId);
      });

      try {
        await client
            .from('user_votes')
            .delete()
            .eq('user_id', user.id)
            .eq('comment_id', commentId);

        await client.from('forum_comments').update({
          'upvotes': comment.upvotes,
          'downvotes': comment.downvotes,
        }).eq('id', commentId);
      } catch (e) {
        setState(() {
          comment.upvotes = oldUpvotes;
          comment.downvotes = oldDownvotes;
          _userCommentVotes[commentId] = currentVote;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove vote: $e')),
          );
        }
      }
      return;
    }

    setState(() {
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

      _userCommentVotes[commentId] = vote;
    });

    try {
      if (currentVote == 0) {
        await client.from('user_votes').insert({
          'user_id': user.id,
          'comment_id': commentId,
          'vote_type': vote,
        });
      } else {
        await client
            .from('user_votes')
            .update({'vote_type': vote})
            .eq('user_id', user.id)
            .eq('comment_id', commentId);
      }

      await client.from('forum_comments').update({
        'upvotes': comment.upvotes,
        'downvotes': comment.downvotes,
      }).eq('id', commentId);
    } catch (e) {
      setState(() {
        comment.upvotes = oldUpvotes;
        comment.downvotes = oldDownvotes;
        if (currentVote == 0) {
          _userCommentVotes.remove(commentId);
        } else {
          _userCommentVotes[commentId] = currentVote;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
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
    DialogHelper.showInputDialog(
      context: context,
      title: 'Reply to u/${parentComment.author}',
      subtitle: 'Share your thoughts on this comment',
      hintText: 'What are your thoughts?',
      confirmText: 'Reply',
      cancelText: 'Cancel',
      icon: Icons.reply_rounded,
      iconColor: Colors.pink[400],
      maxLines: 3,
    ).then((text) async {
      if (text != null && text.isNotEmpty) {
        try {
          final client = _getSupabaseClientOrNull();
          if (client == null) throw Exception('Supabase is not initialized.');
          
          final user = client.auth.currentUser;
          if (user == null) throw Exception('Please sign in to reply.');

          final inserted = await client.from('forum_comments').insert({
            'post_id': widget.post.id,
            'parent_id': parentComment.id,
            'user_id': user.id,
            'author': _resolveAuthorName(user),
            'content': text,
            'upvotes': 0,
            'downvotes': 0,
          }).select().single();

          final newReply = _mapRowToComment(inserted);
          setState(() {
            parentComment.replies.add(newReply);
            widget.post.comments++;
          });

          try {
            await client.from('forum_posts').update({
              'comments_count': widget.post.comments,
            }).eq('id', widget.post.id);
          } catch (_) {}
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Reply posted successfully!'),
                  ],
                ),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to post reply: $e'),
                backgroundColor: Colors.red[600],
              ),
            );
          }
        }
      }
    });
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
      title: 'Managing PCOS symptoms naturally',
      content: 'Has anyone had success with natural remedies for PCOS symptoms?',
      author: 'healthylife',
      postedTime: DateTime.now().subtract(const Duration(hours: 2)),
      upvotes: 24,
      downvotes: 2,
      comments: 15,
      tags: ['natural-remedies', 'symptoms'],
    ),
    ForumPost(
      id: 2,
      title: 'Best exercises for PCOS',
      content: 'What types of exercise have helped you manage PCOS?',
      author: 'fitgirl',
      postedTime: DateTime.now().subtract(const Duration(hours: 5)),
      upvotes: 18,
      downvotes: 1,
      comments: 12,
      tags: ['exercise', 'fitness'],
    ),
  ];
}

