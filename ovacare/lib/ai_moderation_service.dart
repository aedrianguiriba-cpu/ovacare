import 'gemini_moderation_service.dart';

/// Pure Dart + Gemini AI implementation of PCOS content moderation and verification
class AIModerationService {
  // PCOS-related keywords for content verification
  static const List<String> pcosKeywords = [
    'pcos',
    'polycystic',
    'ovarian',
    'cyst',
    'ovary',
    'syndrome',
    'pco',
    'polycystic ovary'
  ];

  static const List<String> relatedKeywords = [
    'cycle',
    'period',
    'hormone',
    'menstrual',
    'fertility',
    'infertility',
    'insulin',
    'diabetes',
    'weight',
    'acne',
    'hirsutism',
    'hair',
    'treatment',
    'medication',
    'metformin',
    'inositol'
  ];

  /// Verify if post content is about PCOS using keyword and heuristic analysis
  static Future<VerificationResult> verifyPcosContent(
      String title, String content) async {
    // Simulate async operation for future compatibility
    await Future.delayed(const Duration(milliseconds: 100));

    final combinedText = '$title $content'.toLowerCase();
    final words = combinedText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Check for meaningful content (at least 4 words with letters)
    final meaningfulWords = words
        .where((w) => w.runes.any((c) => (c >= 97 && c <= 122) || (c >= 65 && c <= 90)) && w.length > 1)
        .toList();
    final hasMeaningfulContent =
        meaningfulWords.length >= 4 && combinedText.toUpperCase() != combinedText;

    // Find terms present in content
    final termsFound = <String>[];
    for (final term in pcosKeywords) {
      if (combinedText.contains(term)) {
        termsFound.add(term);
      }
    }

    // Calculate keyword score
    int relatedCount = 0;

    for (final kw in relatedKeywords) {
      relatedCount += _countOccurrences(combinedText, kw);
    }

    // Semantic similarity using simple term overlap
    double relevanceScore = _calculateRelevanceScore(
        termsFound.length, meaningfulWords.length, relatedCount);

    // More lenient approval for PCOS content
    final hasPcosTerm = termsFound.isNotEmpty;
    const highConfThreshold = 40.0; // Lowered from 70 for better acceptance
    final isApproved = hasMeaningfulContent &&
        (hasPcosTerm || relevanceScore >= highConfThreshold);

    // Suggest tags based on detected terms
    final suggestedTags = _suggestTags(termsFound);

    final reason = isApproved
        ? '✓ Your post is relevant to the PCOS community!'
        : '✗ Your post doesn\'t appear to be about PCOS or related health topics. Please share content about PCOS, menstrual health, hormones, fertility, or treatment experiences.';

    return VerificationResult(
      approved: isApproved,
      isAboutPcos: isApproved,
      relevanceScore: relevanceScore,
      reason: reason,
      termsFound: termsFound,
      suggestedTags: suggestedTags,
      confidence: (relevanceScore / 100.0) > 1.0 ? 1.0 : (relevanceScore / 100.0),
    );
  }

  /// Calculate relevance score based on term presence and content length
  static double _calculateRelevanceScore(
      int termsFoundCount, int meaningfulWordCount, int relatedCount) {
    double score = 0.0;

    // Base score from PCOS terms
    score += termsFoundCount * 30.0;

    // Bonus for meaningful word count
    if (meaningfulWordCount >= 10) {
      score += 20.0;
    } else if (meaningfulWordCount >= 6) {
      score += 10.0;
    }

    // Bonus for related keywords
    score += (relatedCount * 5.0);

    return score > 100.0 ? 100.0 : score;
  }

  /// Count occurrences of a substring in text
  static int _countOccurrences(String text, String pattern) {
    int count = 0;
    int index = 0;
    while ((index = text.indexOf(pattern, index)) != -1) {
      count++;
      index += pattern.length;
    }
    return count;
  }

  /// Suggest tags based on detected terms
  static List<String> _suggestTags(List<String> termsFound) {
    final tagMap = {
      'cycle': 'Discussion',
      'period': 'Symptoms',
      'fertility': 'Fertility',
      'infertility': 'Fertility',
      'insulin': 'Treatment',
      'hormone': 'Treatment',
      'pcos': 'Support',
      'polycystic': 'Support',
      'ovary': 'Symptoms',
      'treatment': 'Treatment',
      'medication': 'Treatment',
      // Tagalog mappings
      'regla': 'Symptoms',
      'irregular': 'Symptoms',
      'irregular na regla': 'Symptoms',
      'walang regla': 'Symptoms',
      'buntis': 'Fertility',
      'pagbubuntis': 'Fertility',
      'gamot': 'Treatment',
      'doktor': 'Treatment',
      'kista': 'Support',
      'ovaryo': 'Symptoms',
      'timbang': 'Lifestyle',
      'dieta': 'Lifestyle',
      'ehersisyo': 'Lifestyle',
      'sintomas': 'Symptoms',
    };

    final suggested = <String>[];
    for (final term in termsFound) {
      final tag = tagMap[term];
      if (tag != null && !suggested.contains(tag) && suggested.length < 3) {
        suggested.add(tag);
      }
    }

    return suggested.isEmpty ? ['Discussion'] : suggested;
  }

  /// Get population cycle statistics
  static CycleStatistics getPopulationStatistics() {
    // Return WHO clinical guideline statistics
    return CycleStatistics(
      averageCycleLength: 28.0,
      stdDevCycleLength: 3.5,
      medianCycleLength: 28.0,
      minCycleLength: 21,
      maxCycleLength: 35,
      averagePeriodLength: 5.0,
      stdDevPeriodLength: 1.8,
      medianPeriodLength: 5.0,
      minPeriodLength: 2,
      maxPeriodLength: 7,
      averageFertileWindowLength: 6.0,
      sampleSize: 0,
      source: 'WHO Clinical Guidelines (Embedded)',
      lastUpdated: DateTime.now().toIso8601String(),
      dataQuality: 'high',
    );
  }

  /// Analyzes if a post is relevant to PCOS and extracts key information
  Future<Map<String, dynamic>> analyzePcosRelevance(String title, String content) async {
    try {
      final fullText = '$title\n$content'.toLowerCase();
      
      // PCOS-related keywords and terms
      const pcosTerms = [
        'pcos', 'polycystic', 'ovary', 'ovarian', 'ovaryo', 'ovaryo', 'hormone', 'insulin',
        'period', 'menstrual', 'regla', 'irregular na regla', 'hindi regular ang regla', 'walang regla', 'cycle', 'irregular', 'fertility', 'pregnancy', 'buntis', 'pagbubuntis',
        'hirsutism', 'hirsutismo', 'sobra ang buhok', 'labis na buhok', 'acne', 'pimples', 'tigyawat', 'weight', 'timbang', 'diet', 'dieta', 'metformin', 'inositol', 'ovulation',
        'androgen', 'testosterone', 'estrogen', 'progesterone', 'cyst', 'kista',
        'ultrasound', 'diagnosis', 'diagnostiko', 'symptom', 'sintomas', 'treatment', 'gamot', 'medication'
      ];

      // Count detected PCOS terms
      final detectedTerms = <String>[];
      for (final term in pcosTerms) {
        if (fullText.contains(term)) {
          detectedTerms.add(term);
        }
      }

      // Calculate relevance score (0.0 to 1.0)
      final relevanceScore = detectedTerms.length / pcosTerms.length;

      // Determine primary topic based on keywords
      String primaryTopic = 'general';
      if (fullText.contains('diet') || fullText.contains('food') || fullText.contains('nutrition')) {
        primaryTopic = 'diet';
      } else if (fullText.contains('exercise') || fullText.contains('fitness') || fullText.contains('workout')) {
        primaryTopic = 'exercise';
      } else if (fullText.contains('hormone') || fullText.contains('medication') || fullText.contains('treatment')) {
        primaryTopic = 'medical';
      } else if (fullText.contains('period') || fullText.contains('menstrual') || fullText.contains('cycle')) {
        primaryTopic = 'menstrual';
      } else if (fullText.contains('fertility') || fullText.contains('pregnancy') || fullText.contains('ovulation')) {
        primaryTopic = 'fertility';
      } else if (fullText.contains('mental') || fullText.contains('anxiety') || fullText.contains('depression')) {
        primaryTopic = 'mental-health';
      }

      // Determine if post is PCOS-relevant (allow 1 core term or related keyword)
      int relatedCount = 0;
      for (final kw in relatedKeywords) {
        relatedCount += _countOccurrences(fullText, kw);
      }

      final isPcosRelevant = detectedTerms.isNotEmpty || relatedCount >= 1;

      return {
        'approved': isPcosRelevant,
        'relevance_score': relevanceScore,
        'primary_topic': primaryTopic,
        'detected_terms': detectedTerms,
        'is_pcos_relevant': isPcosRelevant,
        'message': isPcosRelevant
          ? 'Post is relevant to PCOS'
          : 'Post does not appear to be PCOS-related. Please ensure your post is relevant to PCOS topics. Tip: mention symptoms (period, acne), diagnosis (PCOS), or treatments (metformin).',
      };
    } catch (e) {
      print('Error analyzing PCOS relevance: $e');
      // Default to approved if analysis fails
      return {
        'approved': true,
        'relevance_score': 0.5,
        'primary_topic': 'general',
        'detected_terms': [],
        'is_pcos_relevant': true,
        'message': 'Analysis unavailable',
      };
    }
  }
}

/// Verification result from PCOS content check
class VerificationResult {
  final bool approved;
  final bool isAboutPcos;
  final double relevanceScore;
  final String reason;
  final List<String> termsFound;
  final List<String> suggestedTags;
  final double confidence;

  VerificationResult({
    required this.approved,
    required this.isAboutPcos,
    required this.relevanceScore,
    required this.reason,
    required this.termsFound,
    required this.suggestedTags,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'approved': approved,
        'is_about_pcos': isAboutPcos,
        'relevance_score': relevanceScore,
        'reason': reason,
        'terms_found': termsFound,
        'suggested_tags': suggestedTags,
        'confidence': confidence,
      };
}

/// Population cycle statistics
class CycleStatistics {
  final double averageCycleLength;
  final double stdDevCycleLength;
  final double medianCycleLength;
  final int minCycleLength;
  final int maxCycleLength;
  final double averagePeriodLength;
  final double stdDevPeriodLength;
  final double medianPeriodLength;
  final int minPeriodLength;
  final int maxPeriodLength;
  final double averageFertileWindowLength;
  final int sampleSize;
  final String source;
  final String lastUpdated;
  final String dataQuality;

  CycleStatistics({
    required this.averageCycleLength,
    required this.stdDevCycleLength,
    required this.medianCycleLength,
    required this.minCycleLength,
    required this.maxCycleLength,
    required this.averagePeriodLength,
    required this.stdDevPeriodLength,
    required this.medianPeriodLength,
    required this.minPeriodLength,
    required this.maxPeriodLength,
    required this.averageFertileWindowLength,
    required this.sampleSize,
    required this.source,
    required this.lastUpdated,
    required this.dataQuality,
  });

  Map<String, dynamic> toJson() => {
        'averageCycleLength': averageCycleLength,
        'stdDevCycleLength': stdDevCycleLength,
        'medianCycleLength': medianCycleLength,
        'minCycleLength': minCycleLength,
        'maxCycleLength': maxCycleLength,
        'averagePeriodLength': averagePeriodLength,
        'stdDevPeriodLength': stdDevPeriodLength,
        'medianPeriodLength': medianPeriodLength,
        'minPeriodLength': minPeriodLength,
        'maxPeriodLength': maxPeriodLength,
        'averageFertileWindowLength': averageFertileWindowLength,
        'sampleSize': sampleSize,
        'source': source,
        'lastUpdated': lastUpdated,
        'dataQuality': dataQuality,
      };
}

/// Advanced forum post relevance analyzer for PCOS-related discussions
/// Uses multi-factor AI-like analysis including semantic similarity and context
class ForumRelevanceAnalyzer {
  // Expanded PCOS core terms
  static const List<String> pcosCoreTerms = [
    'pcos',
    'polycystic',
    'ovarian',
    'ovary',
    'cyst',
    'syndrome',
    'androgen',
    'hyperandrogenism',
    'anovulation',
    'amenorrhea'
  ];

  // Symptom-related keywords
  static const List<String> symptomTerms = [
    'symptom',
    'pain',
    'cramping',
    'acne',
    'hirsutism',
    'hair loss',
    'alopecia',
    'fatigue',
    'weight',
    'bloating',
    'irregular',
    'unpredictable',
    'heavy bleeding',
    'absent period',
    'mood swing',
    'depression',
    'anxiety',
    'skin tag',
    'dark patch'
  ];

  // Treatment and medical keywords
  static const List<String> treatmentTerms = [
    'treatment',
    'medication',
    'metformin',
    'spironolactone',
    'birth control',
    'inositol',
    'myo-inositol',
    'd-chiro-inositol',
    'surgery',
    'ovulation',
    'hormone',
    'hormone therapy',
    'laser',
    'electrolysis',
    'fertility',
    'egg',
    'pregnancy'
  ];

  // Lifestyle and wellness keywords
  static const List<String> lifestyleTerms = [
    'diet',
    'nutrition',
    'exercise',
    'workout',
    'fitness',
    'weight loss',
    'metabolism',
    'insulin resistance',
    'insulin sensitivity',
    'stress',
    'sleep',
    'mental health',
    'coping',
    'meditation',
    'yoga',
    'supplement',
    'supplement'
  ];

  // Positive/experience sharing keywords
  static const List<String> experienceTerms = [
    'experience',
    'journey',
    'story',
    'diagnosed',
    'diagnosis',
    'discovered',
    'learned',
    'advice',
    'tip',
    'successful',
    'work',
    'helped',
    'support',
    'community',
    'share'
  ];

  // Red flag terms (spam, off-topic, inappropriate)
  static const List<String> redFlagTerms = [
    'buy',
    'sell',
    'promotion',
    'discount',
    'link',
    'click here',
    'visit',
    'spam',
    'scam',
    'hate',
    'offensive',
    'harassment',
    'abuse'
  ];

  // Question/discussion markers
  static const List<String> questionMarkers = [
    'question',
    'help',
    'advice',
    'should',
    'can',
    'how',
    'why',
    'what',
    'does',
    'anyone',
    'someone',
    'please',
    'tips',
    'recommendations',
    'experience'
  ];

  // TAGALOG - PCOS core terms
  static const List<String> pcosCoreTermsTagalog = [
    'pcos',
    'policistico',
    'polycystic',
    'ovary',
    'ovario',
    'kista',
    'cyst',
    'syndrome',
    'androgen',
    'irregular period',
    'irregular na period',
    'walang period',
    'amenorrhea',
    'amenhorrhea',
    'hormonal imbalance',
    'hormone imbalance',
  ];

  // TAGALOG - Symptom terms
  static const List<String> symptomTermsTagalog = [
    'symptom',
    'symptoms',
    'sakit',
    'symptoms',
    'cramps',
    'cramping',
    'acne',
    'pimples',
    'alahas',
    'buhok',
    'hair',
    'hair loss',
    'pagod',
    'tired',
    'fatigue',
    'timbang',
    'weight',
    'weight gain',
    'bloating',
    'bloat',
    'irregular',
    'hindi regular',
    'heavy bleeding',
    'malaking pagdurugo',
    'mood swing',
    'mood swings',
    'depression',
    'anxiety',
    'stress',
    'skin',
    'dermatitis',
    'breakouts',
    'dark patches',
    'dark areas',
  ];

  // TAGALOG - Treatment terms
  static const List<String> treatmentTermsTagalog = [
    'treatment',
    'treatment',
    'gamot',
    'medicine',
    'metformin',
    'inositol',
    'birth control',
    'contraceptive',
    'kontraseptibo',
    'hormone',
    'hormonal',
    'fertility',
    'fertile',
    'buntis',
    'pregnancy',
    'operation',
    'surgery',
    'operasyon',
    'therapy',
    'therapist',
    'doctor',
    'doktor',
    'physician',
    'spironolactone',
    'pill',
    'supplement',
    'vitamins',
  ];

  // TAGALOG - Lifestyle terms
  static const List<String> lifestyleTermsTagalog = [
    'diet',
    'dieta',
    'kain',
    'food',
    'eating',
    'exercise',
    'ehersisyo',
    'workout',
    'fitness',
    'exercise',
    'stress',
    'stress',
    'tulog',
    'sleep',
    'rest',
    'repose',
    'weight loss',
    'timbang',
    'insulin',
    'mental health',
    'kalusugan',
    'health',
    'wellness',
    'lifestyle',
    'buhay',
  ];

  // TAGALOG - Experience terms
  static const List<String> experienceTermsTagalog = [
    'experience',
    'karanasan',
    'journey',
    'paglalakbay',
    'kwento',
    'story',
    'diagnosed',
    'diagnosed',
    'learned',
    'natuto',
    'naunawaan',
    'advice',
    'payo',
    'tips',
    'success',
    'tagumpay',
    'work',
    'gana',
    'sumusugal',
    'support',
    'tulong',
    'abot-kamay',
    'share',
    'pagbabahagi',
    'sharing',
  ];

  // TAGALOG - Red flag terms
  static const List<String> redFlagTermsTagalog = [
    'bili',
    'bumili',
    'buy',
    'promo',
    'promotion',
    'discount',
    'diskwento',
    'link',
    'click',
    'spam',
    'scam',
    'panggagago',
    'hate',
    'galit',
    'offensive',
    'harassment',
    'abuse',
    'panlalaki',
    'violence',
  ];

  // TAGALOG - Question markers
  static const List<String> questionMarkersTagalog = [
    'tanong',
    'question',
    'help',
    'tulong',
    'payo',
    'advice',
    'dapat',
    'kaya',
    'paano',
    'bakit',
    'ano',
    'sino',
    'tips',
    'suggestions',
    'experience',
    'salamat',
    'thanks',
    'pwede',
    'possible',
    'makakatulong',
  ];

  /// Analyze forum post for PCOS relevance with detailed scoring
  static Future<ForumRelevanceResult> analyzeForum(
    String title,
    String content,
  ) async {
    // Get Gemini AI analysis first (non-blocking)
    final geminiAnalysis = await GeminiModerationService.analyzePostAI(title, content)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => {
            'aiSource': 'Timeout',
            'recommendApproval': null,
            'confidence': 0.0,
            'hasHealthContent': null,
          },
        )
        .catchError((e) => {
          'aiSource': 'Error',
          'recommendApproval': null,
          'confidence': 0.0,
          'hasHealthContent': null,
        });

    // Simulate async for future API integration
    await Future.delayed(const Duration(milliseconds: 50));

    final combinedText = '$title $content'.toLowerCase();
    final titleText = title.toLowerCase();

    // Text preprocessing
    final words = combinedText
        .split(RegExp(r'[\s.,!?;:\-\(\)]+'))
        .where((w) => w.isNotEmpty && w.length > 2)
        .toList();

    // Get Gemini AI insights
    final geminiRecommendation = geminiAnalysis['recommendApproval'];
    final geminiConfidence = (geminiAnalysis['confidence'] as num?)?.toDouble() ?? 0.0;
    final geminiHasHealth = geminiAnalysis['hasHealthContent'] as bool?;
    final aiSource = geminiAnalysis['aiSource'] as String? ?? 'Unknown';
    final geminiIsTagalog = geminiAnalysis['isTagalog'] as bool?;
    final geminiLanguage = geminiAnalysis['language'] as String? ?? 'unknown';
    final geminiDetectedTopics = (geminiAnalysis['detectedTopics'] as List?)?.cast<String>() ?? [];
    final geminiIsRelevant = geminiAnalysis['isRelevant'] as bool?;

    // Log Gemini language detection
    if (geminiIsTagalog == true) {
      print('🇵🇭 Gemini detected Tagalog content (language: $geminiLanguage)');
    }
    if (geminiDetectedTopics.isNotEmpty) {
      print('📋 Gemini detected topics: ${geminiDetectedTopics.join(", ")}');
    }

    // Calculate various relevance scores
    final coreScore = _calculateTermScore(combinedText, pcosCoreTerms) +
        _calculateTermScore(combinedText, pcosCoreTermsTagalog);
    final symptomScore = _calculateTermScore(combinedText, symptomTerms) +
        _calculateTermScore(combinedText, symptomTermsTagalog);
    final treatmentScore = _calculateTermScore(combinedText, treatmentTerms) +
        _calculateTermScore(combinedText, treatmentTermsTagalog);
    final lifestyleScore = _calculateTermScore(combinedText, lifestyleTerms) +
        _calculateTermScore(combinedText, lifestyleTermsTagalog);
    final experienceScore = _calculateTermScore(combinedText, experienceTerms) +
        _calculateTermScore(combinedText, experienceTermsTagalog);

    // Check if it has actual PCOS core terms (not just related keywords)
    final hasPcosCoreTerm = combinedText.contains('pcos') || 
        combinedText.contains('polycystic') ||
        combinedText.contains('ovarian') ||
        combinedText.contains('policistico') ||
        combinedText.contains('kista');

    // Advanced scanning features
    final redFlagScore = _calculateTermScore(combinedText, redFlagTerms) +
        _calculateTermScore(combinedText, redFlagTermsTagalog);
    final questionScore = (_calculateTermScore(combinedText, questionMarkers) +
        _calculateTermScore(combinedText, questionMarkersTagalog)) * 0.5;
    final spamIndicators = _detectSpamIndicators(combinedText);
    final engagementMetrics = _calculateEngagementMetrics(combinedText);

    // Title relevance bonus
    final titleRelevance = _calculateTermScore(titleText, pcosCoreTerms) +
        _calculateTermScore(titleText, pcosCoreTermsTagalog) +
        _calculateTermScore(titleText, symptomTerms) * 0.8 +
        _calculateTermScore(titleText, symptomTermsTagalog) * 0.8;

    // Content quality checks
    final contentLength = words.length;
    final hasGoodLength = contentLength >= 5;
    const isNotAllCaps = true; // No longer check for all caps
    final hasMultipleSentences = RegExp(r'[.!?]').allMatches(combinedText).length >= 2;
    
    // Advanced quality metrics
    final hasProperSpacing = !RegExp(r'  {2,}').hasMatch(combinedText);
    final hasReasonablePunctuation = _checkPunctuationBalance(combinedText);
    final readabilityScore = _calculateReadability(words);

    // Detect engagement signals
    final hasQuestions = _countQuestions(combinedText) > 0;
    final hasCallToAction = questionScore > 0;

    // Calculate composite relevance score with red flag penalty
    final baseRelevanceScore = _calculateCompositeScore(
      coreScore: coreScore,
      symptomScore: symptomScore,
      treatmentScore: treatmentScore,
      lifestyleScore: lifestyleScore,
      experienceScore: experienceScore,
      titleBonus: titleRelevance,
      contentQuality: hasGoodLength && isNotAllCaps && hasMultipleSentences,
    );

    // Apply penalties for spam/red flags
    var finalRelevanceScore = baseRelevanceScore;
    if (redFlagScore > 15) {
      finalRelevanceScore -= redFlagScore * 0.5; // Penalty for spam terms
    }
    if (spamIndicators['isSpam']) {
      finalRelevanceScore -= 20;
    }

    // Gemini AI boost if available and confident
    if (geminiConfidence >= 50) {
      finalRelevanceScore += (geminiConfidence * 0.2);
      print('📊 Gemini boost: +${(geminiConfidence * 0.2).toStringAsFixed(1)}');
    }
    
    if (geminiHasHealth == true) {
      finalRelevanceScore += 15;
      print('🏥 Gemini health boost: +15');
    }

    // Gemini Tagalog detection boost - trust Gemini's language understanding
    if (geminiIsTagalog == true && geminiIsRelevant == true) {
      finalRelevanceScore += 25;
      print('🇵🇭 Gemini Tagalog relevance boost: +25');
    } else if (geminiIsTagalog == true && geminiConfidence >= 40) {
      finalRelevanceScore += 15;
      print('🇵🇭 Gemini Tagalog content boost: +15');
    }

    // Boost for Gemini-detected topics (beyond embedded keywords)
    if (geminiDetectedTopics.isNotEmpty) {
      final topicBoost = geminiDetectedTopics.length * 5.0;
      finalRelevanceScore += topicBoost;
      print('📋 Gemini topics boost: +${topicBoost.toStringAsFixed(1)}');
    }

    // Advanced AI analysis for better accuracy
    final intelligenceScore = _calculateIntelligenceScore(title, content);
    final semanticScore = _analyzeSemanticContext(combinedText, pcosCoreTerms + pcosCoreTermsTagalog);
    final coherenceScore = _analyzeCoherence(content);
    
    // Boost score if post is well-written and coherent
    if (intelligenceScore >= 40) {
      finalRelevanceScore += (intelligenceScore * 0.15); // Boost for good writing
    }
    
    // Add semantic bonus if keywords appear in proper context
    if (semanticScore > 0) {
      finalRelevanceScore += (semanticScore * 0.1);
    }

    if (finalRelevanceScore < 0) finalRelevanceScore = 0;
    if (finalRelevanceScore > 100.0) finalRelevanceScore = 100.0;

    // Enhanced approval logic with Dart AI + Gemini AI
    final postStructure = _analyzePostStructure(title, content);
    final isWellStructured = (postStructure['isQuestion'] || 
        postStructure['isPersonalExperience'] || 
        postStructure['isInformative']);
    
    // Check if Gemini detected relevant Tagalog PCOS content
    final geminiApprovedTagalog = (geminiIsTagalog == true && 
        geminiIsRelevant == true && 
        geminiConfidence >= 40);
    
    // More lenient approval for PCOS-related content
    // Accept a single detected term or related keyword, lower score thresholds
    final hasPcosKeywords = hasPcosCoreTerm || coreScore > 10;
    const relaxedScoreThreshold = 20.0;
    // Accept posts with at least one detected PCOS term OR some related keywords
    final detectedTermsCount = _getDetectedTerms(combinedText).length;
    final hasRelatedKeywords = (symptomScore + treatmentScore + lifestyleScore) > 0;

    final isPcosRelevant = !spamIndicators['isSpam'] &&
      hasProperSpacing &&
      (hasPcosCoreTerm ||
        detectedTermsCount >= 1 ||
        (hasPcosKeywords && finalRelevanceScore >= relaxedScoreThreshold) ||
        geminiApprovedTagalog ||
        hasRelatedKeywords) &&
      contentLength >= 3; // Minimum 3 words (more lenient)

    // Generate detailed feedback
    final feedback = _generateFeedback(
      isPcosRelevant: isPcosRelevant,
      coreScore: coreScore,
      symptomScore: symptomScore,
      treatmentScore: treatmentScore,
      titleBonus: titleRelevance,
      contentLength: contentLength,
      spamDetected: spamIndicators['isSpam'],
      redFlagScore: redFlagScore,
      geminiIsTagalog: geminiIsTagalog,
      geminiDetectedTopics: geminiDetectedTopics,
    );

    // Suggest appropriate tags based on content analysis
    final suggestedTags = _suggestForumTags(
      coreScore: coreScore,
      symptomScore: symptomScore,
      treatmentScore: treatmentScore,
      lifestyleScore: lifestyleScore,
      experienceScore: experienceScore,
    );

    // Detect primary topic
    final primaryTopic = _detectPrimaryTopic(
      symptomScore: symptomScore,
      treatmentScore: treatmentScore,
      lifestyleScore: lifestyleScore,
    );

    return ForumRelevanceResult(
      isRelevant: isPcosRelevant,
      relevanceScore: finalRelevanceScore,
      feedback: feedback,
      suggestedTags: suggestedTags,
      primaryTopic: primaryTopic,
      detectedTerms: _getDetectedTerms(combinedText),
      confidence: (finalRelevanceScore / 100.0) > 1.0 ? 1.0 : (finalRelevanceScore / 100.0),
      contentQualityMetrics: {
        'wordCount': contentLength,
        'hasMultipleSentences': hasMultipleSentences,
        'isProperCapitalization': isNotAllCaps,
        'hasGoodLength': hasGoodLength,
        'hasProperSpacing': hasProperSpacing,
        'hasReasonablePunctuation': hasReasonablePunctuation,
        'aiSource': aiSource,
        'geminiConfidence': geminiConfidence,
        'geminiLanguage': geminiLanguage,
        'geminiIsTagalog': geminiIsTagalog,
        'geminiDetectedTopics': geminiDetectedTopics,
        'geminiApprovedTagalog': geminiApprovedTagalog,
      },
      spamDetected: spamIndicators['isSpam'] as bool,
      readabilityScore: readabilityScore,
      engagementMetrics: engagementMetrics,
      spamIndicators: spamIndicators['indicators'] as List<String>,
    );
  }

  /// Calculate term frequency score
  static double _calculateTermScore(String text, List<String> terms) {
    double score = 0.0;
    for (final term in terms) {
      final pattern = RegExp(r'\b' + RegExp.escape(term) + r'\b');
      final matches = pattern.allMatches(text).length;
      score += matches * 10.0;
    }
    return score > 100.0 ? 100.0 : score;
  }

  /// Calculate weighted composite relevance score
  static double _calculateCompositeScore({
    required double coreScore,
    required double symptomScore,
    required double treatmentScore,
    required double lifestyleScore,
    required double experienceScore,
    required double titleBonus,
    required bool contentQuality,
  }) {
    // Weighted calculation favoring PCOS core terms
    double score = (coreScore * 0.40) +
        (symptomScore * 0.25) +
        (treatmentScore * 0.20) +
        (lifestyleScore * 0.10) +
        (experienceScore * 0.05) +
        titleBonus;

    // Apply content quality multiplier
    if (contentQuality) {
      score *= 1.15;
    }

    return score > 100.0 ? 100.0 : score;
  }

  /// Generate personalized feedback based on analysis
  static String _generateFeedback({
    required bool isPcosRelevant,
    required double coreScore,
    required double symptomScore,
    required double treatmentScore,
    required double titleBonus,
    required int contentLength,
    required bool spamDetected,
    required double redFlagScore,
    bool? geminiIsTagalog,
    List<String> geminiDetectedTopics = const [],
  }) {
    // Check for spam first
    if (spamDetected || redFlagScore > 15) {
      return '⚠️ Your post appears to contain promotional or spam-like content. Please ensure your post is focused on genuine PCOS-related discussion and support.';
    }

    if (!isPcosRelevant) {
      if (contentLength < 5) {
        return '✗ Your post seems quite short. Please add more details about your experience or question related to PCOS, symptoms, treatment, or lifestyle management.';
      }
      return '✗ Your post doesn\'t appear to focus on PCOS or related health topics. Please ensure your post discusses PCOS, its symptoms, treatments, fertility, hormonal health, or related experiences.';
    }

    // Generate positive feedback based on detected topics
    final topics = <String>[];
    if (coreScore > 20) topics.add('PCOS-specific');
    if (symptomScore > 20) topics.add('symptom management');
    if (treatmentScore > 20) topics.add('treatment options');
    
    // Add Gemini-detected topics if available
    if (geminiDetectedTopics.isNotEmpty) {
      for (final topic in geminiDetectedTopics) {
        if (!topics.contains(topic) && topics.length < 5) {
          topics.add(topic);
        }
      }
    }

    // Special message for Tagalog content detected by Gemini
    if (geminiIsTagalog == true) {
      final topicsText = topics.isNotEmpty ? ' tungkol sa ${topics.join(", ")}' : '';
      return '✓ Magandang post$topicsText! Salamat sa iyong pagbabahagi sa PCOS community. (Great post! Thank you for sharing with the PCOS community.)';
    }

    final topicsText =
        topics.isNotEmpty ? ' focusing on ${topics.join(", ")}' : '';
    return '✓ Great post$topicsText! Your contribution will help the PCOS community learn from your experience and perspectives.';
  }

  /// Suggest relevant forum tags based on content
  static List<String> _suggestForumTags({
    required double coreScore,
    required double symptomScore,
    required double treatmentScore,
    required double lifestyleScore,
    required double experienceScore,
  }) {
    final tags = <String>[];

    if (coreScore > 15) tags.add('PCOS Support');
    if (symptomScore > 15) tags.add('Symptoms');
    if (treatmentScore > 15) tags.add('Treatment');
    if (lifestyleScore > 15) tags.add('Lifestyle');
    if (experienceScore > 15) tags.add('Experience');

    // Ensure we have at least one tag
    if (tags.isEmpty) tags.add('Discussion');

    return tags.take(3).toList();
  }

  /// Detect the primary topic of the post
  static String _detectPrimaryTopic({
    required double symptomScore,
    required double treatmentScore,
    required double lifestyleScore,
  }) {
    if (symptomScore > treatmentScore && symptomScore > lifestyleScore) {
      return 'Symptoms & Health';
    } else if (treatmentScore > lifestyleScore) {
      return 'Treatment & Medical';
    } else if (lifestyleScore > 0) {
      return 'Lifestyle & Wellness';
    }
    return 'General Discussion';
  }

  /// Extract detected PCOS-related terms from text
  static List<String> _getDetectedTerms(String text) {
    final detected = <String>[];
    final allTerms = [
      ...pcosCoreTerms,
      ...symptomTerms,
      ...treatmentTerms,
      ...lifestyleTerms,
      ...experienceTerms
    ];

    for (final term in allTerms) {
      if (text.contains(term)) {
        detected.add(term);
      }
    }

    return detected.take(10).toList(); // Return top 10 detected terms
  }

  /// Detect spam indicators in post content
  static Map<String, dynamic> _detectSpamIndicators(String text) {
    int spamScore = 0;
    final indicators = <String>[];

    // Check for excessive URLs
    final urlCount = RegExp(r'http|www|\.com|\.net|\.org').allMatches(text).length;
    if (urlCount > 3) {
      spamScore += 20;
      indicators.add('excessive_urls');
    }

    // Check for repetitive patterns
    final words = text.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      final wordFreq = <String, int>{};
      for (final word in words) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
      final maxFreq = wordFreq.values.fold(0, (a, b) => a > b ? a : b);
      if (maxFreq > words.length * 0.3) {
        // Same word repeated >30% of the time
        spamScore += 15;
        indicators.add('repetitive_content');
      }
    }

    // Check for excessive special characters
    final specialCharCount = RegExp(r'[!@#$%^&*]{2,}').allMatches(text).length;
    if (specialCharCount > 5) {
      spamScore += 10;
      indicators.add('excessive_special_chars');
    }

    // Check for known spam patterns
    if (RegExp(r'(click here|buy now|limited time|act now)', 
        caseSensitive: false).hasMatch(text)) {
      spamScore += 25;
      indicators.add('spam_patterns');
    }

    return {
      'isSpam': spamScore >= 30,
      'spamScore': spamScore.toDouble(),
      'indicators': indicators,
    };
  }

  /// Count questions in content
  static int _countQuestions(String text) {
    return RegExp(r'\?').allMatches(text).length;
  }

  /// Calculate engagement metrics
  static Map<String, double> _calculateEngagementMetrics(String text) {
    final questions = _countQuestions(text);
    final exclamations = RegExp(r'!').allMatches(text).length;
    final periods = RegExp(r'\.').allMatches(text).length;

    final totalSentences = questions + exclamations + periods;
    final engagementLevel = totalSentences > 0 
        ? ((questions + exclamations * 0.5) / totalSentences) * 100 
        : 0.0;

    return {
      'questions': questions.toDouble(),
      'exclamations': exclamations.toDouble(),
      'engagement_level': engagementLevel,
    };
  }

  /// Check if punctuation is balanced and reasonable
  static bool _checkPunctuationBalance(String text) {
    final openParen = RegExp(r'\(').allMatches(text).length;
    final closeParen = RegExp(r'\)').allMatches(text).length;
    final openBracket = RegExp(r'\[').allMatches(text).length;
    final closeBracket = RegExp(r'\]').allMatches(text).length;

    // Check for balanced brackets/parentheses
    if (openParen != closeParen || openBracket != closeBracket) {
      return false;
    }

    return true;
  }

  /// Calculate readability score based on word analysis
  static double _calculateReadability(List<String> words) {
    if (words.isEmpty) return 0.0;

    // Average word length (ideal 4-8 characters for readability)
    final avgWordLength = words.fold(0, (sum, w) => sum + w.length) / words.length;
    
    // Penalize if average word is too long or too short
    double readabilityScore = 50.0;
    
    if (avgWordLength >= 4 && avgWordLength <= 8) {
      readabilityScore += 25; // Good readability
    } else if (avgWordLength > 10) {
      readabilityScore -= 15; // Too many complex words
    } else if (avgWordLength < 3) {
      readabilityScore -= 10; // Too many very short words
    }

    // Bonus for varied word lengths
    final wordLengths = words.map((w) => w.length).toSet();
    if (wordLengths.length > words.length * 0.4) {
      readabilityScore += 15; // Good word variety
    }

    return readabilityScore > 100.0 ? 100.0 : readabilityScore;
  }

  /// Advanced semantic analysis for content understanding
  static double _analyzeSemanticContext(String text, List<String> keywords) {
    final sentences = text.split(RegExp(r'[.!?]+'));
    double contextScore = 0.0;
    
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      
      final sentenceWords = sentence.toLowerCase().split(RegExp(r'\s+'));
      int keywordCount = 0;
      
      for (final keyword in keywords) {
        if (sentenceWords.contains(keyword)) {
          keywordCount++;
        }
      }
      
      // Bonus if multiple keywords in same sentence (indicates semantic relevance)
      if (keywordCount >= 2) {
        contextScore += 15.0;
      } else if (keywordCount >= 1) {
        contextScore += 5.0;
      }
    }
    
    return contextScore;
  }

  /// Detect writing quality and coherence
  static double _analyzeWritingQuality(String text) {
    double qualityScore = 50.0;
    
    // Check for proper capitalization
    final hasCapitalizedStart = RegExp(r'^[A-Z]').hasMatch(text);
    if (hasCapitalizedStart) qualityScore += 10;
    
    // Check for sentence variety
    final sentences = text.split(RegExp(r'[.!?]+'));
    final sentenceLengths = sentences
        .map((s) => s.trim().split(RegExp(r'\s+')).length)
        .where((len) => len > 0)
        .toList();
    
    if (sentenceLengths.isNotEmpty) {
      final avgLen = sentenceLengths.fold<int>(0, (sum, len) => sum + len) / sentenceLengths.length;
      // Varied sentence lengths indicate better writing
      if (avgLen > 5 && avgLen < 20) qualityScore += 15;
    }
    
    // Check for excessive punctuation or caps
    final excessivePunctuation = RegExp(r'[!?]{2,}').hasMatch(text);
    if (excessivePunctuation) qualityScore -= 20;
    
    // Check for repeated characters (e.g., "looooool")
    final repeatedChars = RegExp(r'(.)\1{3,}').hasMatch(text);
    if (repeatedChars) qualityScore -= 25;
    
    if (qualityScore < 0) qualityScore = 0.0;
    if (qualityScore > 100.0) qualityScore = 100.0;
    return qualityScore;
  }

  /// Analyze post intent and structure
  static Map<String, dynamic> _analyzePostStructure(String title, String content) {
    final titleWords = title.split(RegExp(r'\s+'));
    final contentSentences = content.split(RegExp(r'[.!?]+'));
    
    // Detect question posts
    final hasQuestion = content.contains('?');
    final questionCount = RegExp(r'\?').allMatches(content).length;
    
    // Detect personal experience posts
    final personalMarkers = ['i ', 'my ', 'me ', 'we ', 'our '];
    final personalCount = personalMarkers.fold<int>(0, (sum, marker) {
      return sum + RegExp(marker, caseSensitive: false).allMatches(content).length;
    });
    
    // Detect advice/help seeking
    final helpMarkers = ['help', 'please', 'anyone', 'advice', 'how', 'why', 'should'];
    final helpCount = helpMarkers.fold<int>(0, (sum, marker) {
      return sum + RegExp(marker, caseSensitive: false).allMatches(content).length;
    });
    
    // Detect informative posts
    final infoMarkers = ['research', 'study', 'found', 'article', 'read', 'shared', 'discovered'];
    final infoCount = infoMarkers.fold<int>(0, (sum, marker) {
      return sum + RegExp(marker, caseSensitive: false).allMatches(content).length;
    });
    
    return {
      'isQuestion': hasQuestion,
      'questionCount': questionCount,
      'isPersonalExperience': personalCount > 2,
      'isHelpSeeking': helpCount >= 2,
      'isInformative': infoCount >= 2,
      'titleLength': titleWords.length,
      'contentDepth': contentSentences.length,
    };
  }

  /// Validate coherence and logical flow
  static double _analyzeCoherence(String text) {
    double coherenceScore = 0.0;
    
    // Check for logical connectors (indicates organized thinking)
    final connectors = ['because', 'however', 'therefore', 'also', 'furthermore', 'moreover', 'but', 'and'];
    final connectorCount = connectors.fold<int>(0, (sum, conn) {
      return sum + RegExp(conn, caseSensitive: false).allMatches(text).length;
    });
    
    if (connectorCount >= 2) coherenceScore += 20;
    if (connectorCount >= 4) coherenceScore += 20;
    
    // Check for topic consistency (related words should appear multiple times)
    final sentences = text.split(RegExp(r'[.!?]+'));
    if (sentences.length >= 3) coherenceScore += 15;
    if (sentences.length >= 5) coherenceScore += 15;
    
    // Check if text maintains focus (not randomly jumping topics)
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final uniqueWords = words.toSet().length;
    final wordRepetitionRatio = uniqueWords / (words.isNotEmpty ? words.length : 1);
    
    // Good coherence has some word repetition (0.4-0.7 ratio)
    if (wordRepetitionRatio >= 0.4 && wordRepetitionRatio <= 0.7) {
      coherenceScore += 20;
    }
    
    return coherenceScore > 100.0 ? 100.0 : coherenceScore;
  }

  /// Enhanced analysis that combines multiple AI techniques
  static double _calculateIntelligenceScore(String title, String content) {
    final structure = _analyzePostStructure(title, content);
    final writingQuality = _analyzeWritingQuality(content);
    final coherence = _analyzeCoherence(content);
    
    double intelligence = 0.0;
    
    // Bonus for well-structured posts
    if (structure['isQuestion'] || structure['isPersonalExperience'] || structure['isInformative']) {
      intelligence += 20;
    }
    
    // Combine scores
    intelligence += (writingQuality * 0.3);
    intelligence += (coherence * 0.3);
    
    // Bonus for depth and engagement
    if ((structure['contentDepth'] as int) >= 4) intelligence += 10;
    if ((structure['titleLength'] as int) >= 3) intelligence += 5;
    
    return intelligence > 100.0 ? 100.0 : intelligence;
  }
}

/// Result of forum post relevance analysis
class ForumRelevanceResult {
  final bool isRelevant;
  final double relevanceScore;
  final String feedback;
  final List<String> suggestedTags;
  final String primaryTopic;
  final List<String> detectedTerms;
  final double confidence;
  final Map<String, dynamic> contentQualityMetrics;
  final bool spamDetected;
  final double readabilityScore;
  final Map<String, dynamic> engagementMetrics;
  final List<String> spamIndicators;

  ForumRelevanceResult({
    required this.isRelevant,
    required this.relevanceScore,
    required this.feedback,
    required this.suggestedTags,
    required this.primaryTopic,
    required this.detectedTerms,
    required this.confidence,
    required this.contentQualityMetrics,
    this.spamDetected = false,
    this.readabilityScore = 0.0,
    this.engagementMetrics = const {},
    this.spamIndicators = const [],
  });

  Map<String, dynamic> toJson() => {
        'isRelevant': isRelevant,
        'relevanceScore': relevanceScore,
        'feedback': feedback,
        'suggestedTags': suggestedTags,
        'primaryTopic': primaryTopic,
        'detectedTerms': detectedTerms,
        'confidence': confidence,
        'contentQualityMetrics': contentQualityMetrics,
        'spamDetected': spamDetected,
        'readabilityScore': readabilityScore,
        'engagementMetrics': engagementMetrics,
        'spamIndicators': spamIndicators,
      };
}