# Forum AI Integration - Implementation Examples

## Code Examples

### 1. Using ForumRelevanceAnalyzer

```dart
// Import the service
import 'ai_moderation_service.dart';

// Analyze a forum post
final result = await ForumRelevanceAnalyzer.analyzeForum(
  title: "My PCOS Diagnosis Journey",
  content: "I was recently diagnosed with PCOS. My symptoms include irregular periods, acne, and hair loss...",
);

// Check if approved
if (result.isRelevant) {
  print("✅ Post approved!");
  print("Score: ${result.relevanceScore}%");
  print("Topic: ${result.primaryTopic}");
  print("Tags: ${result.suggestedTags}");
} else {
  print("❌ Post needs improvement");
  print("Feedback: ${result.feedback}");
}

// Output:
// ✅ Post approved!
// Score: 85.0%
// Topic: Symptoms & Health
// Tags: [Symptoms, PCOS Support, Experience]
```

### 2. Creating a Forum Post with AI Analysis

```dart
// User-submitted content
final userTitle = "Questions about Metformin";
final userContent = "I just started metformin for my PCOS treatment. How long does it take to work?";

// Analyze relevance
final analysis = await _analyzePostRelevance(userTitle, userContent);

// Create post with AI metadata
final newPost = ForumPost(
  id: nextId,
  title: userTitle,
  content: userContent,
  author: currentUser,
  postedTime: DateTime.now(),
  upvotes: 1,
  downvotes: 0,
  comments: 0,
  tags: analysis['suggested_tags'] as List<String>,
  // AI fields
  relevanceScore: analysis['score'] as double,
  primaryTopic: analysis['primary_topic'] as String,
  detectedPcosTerms: analysis['detected_terms'] as List<String>,
  isPcosRelevant: analysis['approved'] as bool,
);

// Add to forum
_posts.add(newPost);
```

### 3. Displaying Post with Relevance Indicators

```dart
// In _buildPostCard() method
Widget _buildRelevanceIndicator(ForumPost post) {
  if (!post.isPcosRelevant || post.relevanceScore == null) {
    return const SizedBox.shrink();
  }

  return Row(
    children: [
      Icon(
        Icons.verified_user,
        size: 16,
        color: _getRelevanceColor(post.relevanceScore ?? 0),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post.primaryTopic ?? 'PCOS Related',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getRelevanceColor(post.relevanceScore ?? 0),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRelevanceColor(post.relevanceScore ?? 0)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(post.relevanceScore ?? 0).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRelevanceColor(post.relevanceScore ?? 0),
                    ),
                  ),
                ),
              ],
            ),
            if ((post.detectedPcosTerms?.length ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Detected: ${post.detectedPcosTerms!.take(2).join(", ")}...',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

Color _getRelevanceColor(double score) {
  if (score >= 70) return Colors.green;
  if (score >= 50) return Colors.orange;
  return Colors.amber;
}
```

### 4. Enhanced Post Rejection Handling

```dart
// Show detailed feedback for rejected posts
if (!analysis['approved']) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Post Needs Adjustment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(analysis['reason']),
            const SizedBox(height: 16),
            if ((analysis['detected_terms'] as List?)?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggestions to improve:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Include more PCOS-related terms\n'
                      '• Provide more detail\n'
                      '• Focus on health topics',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Edit Post'),
        ),
      ],
    ),
  );
}
```

### 5. Customizing Keywords (Advanced)

```dart
// To add new PCOS-related keywords:
static const List<String> pcosKeywords = [
  'pcos',
  'polycystic',
  'ovarian',
  'ovary',
  'cyst',
  'syndrome',
  'androgen',
  'hyperandrogenism',
  'anovulation',
  'amenorrhea',
  // Add your custom terms here
];

// To add new symptom keywords:
static const List<String> symptomTerms = [
  'symptom',
  'pain',
  'cramping',
  'acne',
  'hirsutism',
  'hair loss',
  // Add custom symptoms
];

// Recompile and the analyzer will use new keywords automatically
```

### 6. Accessing Detailed Analysis Results

```dart
// Get full ForumRelevanceResult object
final fullResult = await ForumRelevanceAnalyzer.analyzeForum(
  title: postTitle,
  content: postContent,
);

// Access all properties
print('Relevant: ${fullResult.isRelevant}');
print('Score: ${fullResult.relevanceScore}');
print('Feedback: ${fullResult.feedback}');
print('Suggested Tags: ${fullResult.suggestedTags}');
print('Primary Topic: ${fullResult.primaryTopic}');
print('Detected Terms: ${fullResult.detectedTerms}');
print('Confidence: ${fullResult.confidence}');
print('Content Quality: ${fullResult.contentQualityMetrics}');

// Convert to JSON for storage/transmission
final json = fullResult.toJson();
print(json);
// {
//   'isRelevant': true,
//   'relevanceScore': 85.0,
//   'feedback': '✓ Great post focusing on symptom management!',
//   'suggestedTags': ['Symptoms', 'Support'],
//   'primaryTopic': 'Symptoms & Health',
//   'detectedTerms': ['pcos', 'acne', 'irregular'],
//   'confidence': 0.85,
//   'contentQualityMetrics': {...}
// }
```

### 7. Batch Analysis (Multiple Posts)

```dart
// Analyze multiple posts at once
Future<List<ForumRelevanceResult>> analyzePosts(List<ForumPost> posts) async {
  final results = <ForumRelevanceResult>[];
  
  for (final post in posts) {
    final result = await ForumRelevanceAnalyzer.analyzeForum(
      post.title,
      post.content,
    );
    results.add(result);
  }
  
  return results;
}

// Usage
final allPosts = _posts;
final analysisResults = await analyzePosts(allPosts);

// Filter approved posts
final approvedPosts = allPosts
    .asMap()
    .entries
    .where((e) => analysisResults[e.key].isRelevant)
    .map((e) => e.value)
    .toList();

// Sort by relevance score
final sortedByRelevance = allPosts
    .asMap()
    .entries
    .toList()
    ..sort((a, b) => analysisResults[b.key].relevanceScore
        .compareTo(analysisResults[a.key].relevanceScore))
    .map((e) => e.value)
    .toList();
```

### 8. Fallback to Basic Moderation

```dart
// If advanced analyzer fails, fallback to basic check
Future<Map<String, dynamic>> _analyzePostRelevance(
  String title,
  String content,
) async {
  try {
    // Try advanced analysis first
    final result = await ForumRelevanceAnalyzer.analyzeForum(
      title,
      content,
    );
    
    return {
      'approved': result.isRelevant,
      'reason': result.feedback,
      'score': result.relevanceScore,
      'suggested_tags': result.suggestedTags,
    };
  } catch (e) {
    // Fallback to basic keyword check
    try {
      final basicResult = await AIModerationService.verifyPcosContent(
        title,
        content,
      );
      
      return {
        'approved': basicResult.approved,
        'reason': basicResult.reason,
        'score': basicResult.relevanceScore,
        'suggested_tags': basicResult.suggestedTags,
      };
    } catch (fallbackError) {
      // If both fail, default to approval with warning
      return {
        'approved': true,
        'reason': 'Analysis temporarily unavailable',
        'score': 50.0,
        'suggested_tags': ['Discussion'],
      };
    }
  }
}
```

### 9. User Experience Enhancement

```dart
// Show animated loading state during analysis
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
        SizedBox(height: 8),
        Text(
          'This helps keep our community focused on PCOS topics',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
  ),
);

// Perform analysis
final result = await _analyzePostRelevance(title, content);

// Close loading and show result
Navigator.pop(context);

if (result['approved']) {
  // Show success with details
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result['reason']),
          const SizedBox(height: 4),
          Text(
            '${result['primary_topic']} (${result['score']}%)',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
    ),
  );
} else {
  // Show detailed rejection with suggestions
  showDetailedFeedback(context, result);
}
```

### 10. Stats and Monitoring

```dart
// Track forum analytics
class ForumStats {
  int totalPosts = 0;
  int approvedPosts = 0;
  int rejectedPosts = 0;
  double averageRelevance = 0.0;
  Map<String, int> topicCounts = {};
  
  void updateStats(ForumRelevanceResult result) {
    totalPosts++;
    
    if (result.isRelevant) {
      approvedPosts++;
      
      // Update average
      averageRelevance = 
        (averageRelevance * (totalPosts - 1) + result.relevanceScore) / 
        totalPosts;
      
      // Track topics
      topicCounts[result.primaryTopic] = 
        (topicCounts[result.primaryTopic] ?? 0) + 1;
    } else {
      rejectedPosts++;
    }
  }
  
  void printStats() {
    print('📊 Forum Statistics:');
    print('Total Posts: $totalPosts');
    print('Approved: $approvedPosts (${(approvedPosts/totalPosts*100).toStringAsFixed(1)}%)');
    print('Rejected: $rejectedPosts');
    print('Avg Relevance: ${averageRelevance.toStringAsFixed(1)}%');
    print('Topics:');
    topicCounts.forEach((topic, count) {
      print('  - $topic: $count');
    });
  }
}

// Usage
final stats = ForumStats();
for (final post in _posts) {
  final result = await ForumRelevanceAnalyzer.analyzeForum(
    post.title,
    post.content,
  );
  stats.updateStats(result);
}
stats.printStats();
```

## Best Practices

1. **Always handle errors gracefully** - Fallback to basic checks
2. **Cache results** - Don't re-analyze same posts
3. **Use async/await** - Never block UI during analysis
4. **Provide feedback** - Always tell user why post was approved/rejected
5. **Be transparent** - Show relevance scores and detected terms
6. **Monitor performance** - Track false positives/negatives
7. **Iterate on keywords** - Add new terms based on community feedback

## Troubleshooting

**Issue**: Analysis is too strict/lenient
- **Solution**: Adjust score thresholds in `_analyzePostRelevance()`

**Issue**: Important PCOS terms not recognized
- **Solution**: Add to keyword lists in `ForumRelevanceAnalyzer`

**Issue**: Posts taking too long to analyze
- **Solution**: Analysis is async by design, check for network issues

**Issue**: False positives/negatives
- **Solution**: Collect feedback and adjust weights in scoring formula

---

**Ready to integrate?** See FORUM_AI_INTEGRATION.md for full documentation.
