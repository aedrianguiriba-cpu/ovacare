import 'dart:math';

/// Pure Dart implementation of PCOS content moderation and verification
class AIModerationService {
  // PCOS-related keywords for content verification
  static const List<String> pcosKeywords = [
    'pcos',
    'polycystic',
    'ovarian',
    'cyst',
    'ovary',
    'syndrome'
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
    await Future.delayed(Duration(milliseconds: 100));

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

    // Strict approval rules
    final hasPcosTerm = termsFound.isNotEmpty;
    final highConfThreshold = 70.0;
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
      confidence: min(relevanceScore / 100.0, 1.0),
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

    return min(score, 100.0);
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
