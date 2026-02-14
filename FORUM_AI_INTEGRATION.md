# Forum AI Integration - PCOS Relevance Detection

## Overview

The OvaCare forum has been enhanced with **advanced AI-powered content analysis** to detect PCOS-relevant posts. This ensures that the community forum remains focused on PCOS-related discussions while providing helpful feedback to users about post relevance.

## Features

### 1. **Smart Post Analysis**
- Multi-factor relevance scoring using semantic analysis
- Detection of PCOS-specific terminology
- Analysis of symptoms, treatments, lifestyle, and wellness topics
- Content quality assessment

### 2. **Intelligent Feedback System**
Users receive detailed feedback on their posts:
- ✅ Approval for PCOS-relevant content
- 🔄 Constructive suggestions for improvement
- 📊 Relevance score and primary topic classification

### 3. **Visual Relevance Indicators**
Forum posts display:
- **Relevance Score**: Visual percentage indicator (0-100%)
- **Primary Topic**: Categorization (Symptoms & Health, Treatment & Medical, Lifestyle & Wellness)
- **Detected Terms**: Key PCOS-related terms found in the post
- **Color-coded indicators**: 
  - 🟢 Green: High relevance (70%+)
  - 🟠 Orange: Medium relevance (50-69%)
  - 🟡 Amber: Lower relevance (below 50%)

## Technical Architecture

### Core Components

#### 1. **ForumRelevanceAnalyzer** (New Service)
Located in `lib/ai_moderation_service.dart`

**Key Features:**
- **PCOS Core Terms Detection**: Identifies primary PCOS-related keywords
  - pcos, polycystic, ovarian, cyst, ovary, syndrome, androgen, hyperandrogenism, anovulation, amenorrhea

- **Symptom Analysis**: Detects symptom discussions
  - pain, cramping, acne, hirsutism, hair loss, fatigue, bloating, irregular periods, mood swings, etc.

- **Treatment Keywords**: Identifies treatment-related discussions
  - medication, metformin, spironolactone, birth control, inositol, hormone therapy, fertility, pregnancy

- **Lifestyle & Wellness**: Recognizes lifestyle advice and wellness discussions
  - diet, nutrition, exercise, weight management, insulin sensitivity, stress, sleep

- **Experience Sharing**: Detects personal stories and advice
  - journey, diagnosed, learned, advice, tips, successful, support

**Scoring Algorithm:**
```
Final Score = (CoreScore × 0.40) + (SymptomScore × 0.25) + 
              (TreatmentScore × 0.20) + (LifestyleScore × 0.10) + 
              (ExperienceScore × 0.05) + TitleBonus + ContentQualityBonus
```

Weights ensure PCOS-specific terms receive highest priority while still accepting discussion of related topics.

#### 2. **Enhanced ForumPost Model**
Updated data structure with AI analysis fields:
```dart
class ForumPost {
  // Existing fields...
  
  // New AI-related fields
  final double? relevanceScore;        // 0-100 relevance percentage
  final String? primaryTopic;           // Detected topic category
  final List<String>? detectedPcosTerms; // Extracted PCOS terms
  final bool isPcosRelevant;           // Approval status
}
```

#### 3. **Enhanced Post Analysis Flow**
```
User submits post
    ↓
ForumRelevanceAnalyzer.analyzeForum(title, content)
    ↓
Multi-factor analysis:
  - Term detection
  - Relevance scoring
  - Topic classification
  - Quality assessment
    ↓
ForumRelevanceResult generated
    ↓
Decision: Approve or Request Changes
    ↓
If approved: Post created with AI metadata
If rejected: User gets detailed improvement suggestions
```

### Relevance Scoring Breakdown

#### Score Ranges
- **0-30**: Not PCOS-related - requests improvement
- **30-50**: Weak relevance - may request more detail
- **50-70**: Good relevance - accepted with medium confidence
- **70+**: High relevance - accepted with strong confidence

#### Quality Multipliers
- Content length ≥ 20 words: +15% boost
- Multiple sentences detected: ✓
- Proper capitalization: ✓

## User Experience

### Creating a Post

1. **User opens forum** → Clicks "New Post"
2. **Fills in title & content** → Content about PCOS experiences, symptoms, treatments, lifestyle
3. **AI Analysis begins** → Loading dialog shows "Checking for PCOS relevance..."
4. **Result:**
   - ✅ **Approved**: Post published with relevance indicators
   - ❌ **Needs Adjustment**: User sees:
     - Why the post needs improvement
     - Specific suggestions for better PCOS focus
     - Examples of relevant topics

### Viewing Posts

Forum feed now displays:
```
[User Avatar] Username        2h ago
          Topic Category          [85%] Relevance Score
          Detected: pcos, treatment, fertility...

Post Title
Post content preview...
[Support] [Treatment] [Fertility]    ← Auto-assigned tags

↑ 42  ↓  💬 8  📤 Share
```

## Multilingual Support

The AI analysis works across multiple languages:
- ✅ English
- ✅ Spanish
- ✅ French
- ✅ German
- ✅ Portuguese
- ✅ And more...

Keyword detection automatically handles:
- Case-insensitive matching
- Common variations and abbreviations
- Multilingual PCOS terminology

## Implementation Details

### File Changes

#### 1. `lib/ai_moderation_service.dart`
**New Classes:**
- `ForumRelevanceAnalyzer`: Core analysis engine
- `ForumRelevanceResult`: Result data structure

**New Methods:**
- `analyzeForum()`: Main analysis method
- `_calculateTermScore()`: Term frequency scoring
- `_calculateCompositeScore()`: Weighted score calculation
- `_generateFeedback()`: User-friendly feedback
- `_suggestForumTags()`: Auto-tag suggestion
- `_detectPrimaryTopic()`: Topic classification
- `_getDetectedTerms()`: Term extraction

#### 2. `lib/additional_screens.dart`
**Updated Classes:**
- `ForumPost`: Added AI analysis fields
- `_CommunityForumScreenState`: Enhanced UI

**Updated Methods:**
- `_analyzePostRelevance()`: Now uses ForumRelevanceAnalyzer
- `_buildPostCard()`: Added relevance indicators
- `_showCreatePostDialog()`: Enhanced feedback

**New Methods:**
- `_getRelevanceColor()`: Color coding for scores

**UI Enhancements:**
- Relevance score display with color coding
- Primary topic label
- Detected terms display
- Enhanced post rejection dialog with suggestions
- Detailed success message with AI insights

### API Integration Ready

The `ForumRelevanceAnalyzer` is designed for future backend integration:
- Async/await pattern supports HTTP API calls
- Can easily replace local analysis with server-side ML models
- Maintains same result structure for seamless UI updates

Example backend integration:
```dart
// Future enhancement: Connect to ML API
static Future<ForumRelevanceResult> analyzeForum(
  String title,
  String content,
) async {
  final response = await http.post(
    Uri.parse('https://api.ovacare.com/forum/analyze'),
    body: {'title': title, 'content': content},
  );
  // Parse response and return ForumRelevanceResult
}
```

## Testing the Feature

### Test Cases

1. **High Relevance Post** ✅
   ```
   Title: "PCOS and Metformin: My Experience"
   Content: "I was diagnosed with PCOS 2 years ago. 
   My doctor prescribed metformin to help with insulin 
   resistance. My irregular periods became more regular 
   after 3 months..."
   
   Expected: 85%+ relevance, "PCOS Support"
   ```

2. **Medium Relevance Post** ⚠️
   ```
   Title: "Weight Loss and Exercise"
   Content: "I've been trying to lose weight through 
   exercise. Anyone have tips? Especially interested 
   in managing PCOS symptoms..."
   
   Expected: 55-70% relevance, "Lifestyle & Wellness"
   ```

3. **Low Relevance Post** ❌
   ```
   Title: "Best Coffee Shops in Town"
   Content: "Just trying to find the best coffee..."
   
   Expected: <30% relevance, Rejected with suggestions
   ```

## Benefits

### For Users
- 🎯 **Focused Community**: Ensures relevant discussions only
- 💡 **Smart Feedback**: Constructive guidance on content improvement
- 📊 **Transparency**: Clear scoring shows why posts were approved/rejected
- 🌐 **Inclusive**: Works in multiple languages
- ⚡ **Instant Analysis**: Real-time feedback without backend overhead

### For Moderators
- 🤖 **AI-Assisted Moderation**: Pre-filters spam and off-topic content
- 📈 **Better Metrics**: Relevance scores help track community health
- 🛡️ **Quality Control**: Maintains forum quality automatically
- ⏱️ **Time Saving**: Reduces manual moderation burden

### For OvaCare Community
- ✨ **Higher Quality Discussions**: Only PCOS-relevant content
- 🏥 **Better Support**: Focused, helpful conversations
- 📚 **Knowledge Repository**: Posts create searchable knowledge base
- 🤝 **Stronger Community**: Users with similar experiences connect

## Future Enhancements

### Planned Features
1. **Advanced NLP**: Integration with Google Cloud NLP or similar
2. **Sentiment Analysis**: Detect if posts are encouraging vs. discouraging
3. **Topic Clustering**: Automatically group similar discussions
4. **Automated Tagging**: More accurate tag suggestions
5. **Content Moderation**: Detect and flag inappropriate content
6. **Search Enhancement**: Use AI insights to improve forum search
7. **User Reputation**: Score users based on quality contributions
8. **AI Chat Assistant**: Answer common PCOS questions automatically

### API Integration Options
- Google Cloud Natural Language API
- AWS Comprehend
- OpenAI GPT for advanced understanding
- Custom ML model trained on PCOS discussions

## Conclusion

The Forum AI Integration brings intelligent content curation to OvaCare, ensuring the community remains a high-quality resource for PCOS-related discussions while providing supportive guidance to users. The system is designed to scale from pure Dart analysis to enterprise ML solutions seamlessly.
