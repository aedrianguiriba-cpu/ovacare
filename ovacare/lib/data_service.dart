import 'pcos_datasets.dart';

/// Represents population-level cycle statistics from online datasets
class PopulationCycleData {
  final double averageCycleLength;
  final double averagePeriodLength;
  final double stdDevCycleLength;
  final double stdDevPeriodLength;
  final double averageFertileWindowLength;
  final int sampleSize;
  final String source;
  final DateTime lastUpdated;

  PopulationCycleData({
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.stdDevCycleLength,
    required this.stdDevPeriodLength,
    required this.averageFertileWindowLength,
    required this.sampleSize,
    required this.source,
    required this.lastUpdated,
  });

  factory PopulationCycleData.fromJson(Map<String, dynamic> json) {
    return PopulationCycleData(
      averageCycleLength: (json['averageCycleLength'] as num).toDouble(),
      averagePeriodLength: (json['averagePeriodLength'] as num).toDouble(),
      stdDevCycleLength: (json['stdDevCycleLength'] as num).toDouble(),
      stdDevPeriodLength: (json['stdDevPeriodLength'] as num).toDouble(),
      averageFertileWindowLength: (json['averageFertileWindowLength'] as num).toDouble(),
      sampleSize: json['sampleSize'] as int,
      source: json['source'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'averageCycleLength': averageCycleLength,
    'averagePeriodLength': averagePeriodLength,
    'stdDevCycleLength': stdDevCycleLength,
    'stdDevPeriodLength': stdDevPeriodLength,
    'averageFertileWindowLength': averageFertileWindowLength,
    'sampleSize': sampleSize,
    'source': source,
    'lastUpdated': lastUpdated.toIso8601String(),
  };
}

/// Comparative analysis between user's cycle and population data
class CycleComparison {
  final double userCycleLength;
  final double populationCycleLength;
  final double cycleVariance; // positive = longer than average, negative = shorter
  final double userPeriodLength;
  final double populationPeriodLength;
  final double periodVariance;
  final String interpretation;
  final double confidence; // 0.0 - 1.0 based on how much data is available

  CycleComparison({
    required this.userCycleLength,
    required this.populationCycleLength,
    required this.cycleVariance,
    required this.userPeriodLength,
    required this.populationPeriodLength,
    required this.periodVariance,
    required this.interpretation,
    required this.confidence,
  });
}

class DataService {
  PopulationCycleData? _cachedData;
  DateTime? _cacheTime;

  /// Get population-level cycle statistics from embedded datasets
  /// No network calls needed - all data is embedded locally
  Future<PopulationCycleData> getPopulationCycleData() async {
    // Return cached data if still fresh
    if (_cachedData != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!).inHours < 24) {
        return _cachedData!;
      }
    }

    // Use embedded PCOS datasets (pure local data, no network)
    const stats = PCOSMonitoringDatasets.populationCycleStats;
    final data = PopulationCycleData(
      averageCycleLength: (stats['average_cycle_length'] as num).toDouble(),
      averagePeriodLength: (stats['average_period_length'] as num).toDouble(),
      stdDevCycleLength: (stats['std_dev_cycle'] as num).toDouble(),
      stdDevPeriodLength: (stats['std_dev_period'] as num).toDouble(),
      averageFertileWindowLength: (stats['fertile_window_length'] as num).toDouble(),
      sampleSize: stats['sample_size'] as int,
      source: stats['source'] as String,
      lastUpdated: DateTime.now(),
    );

    _cachedData = data;
    _cacheTime = DateTime.now();
    return data;
  }

  /// Compare user's cycle data with population statistics
  CycleComparison compareUserToCycleData(
    int userAvgCycleLength,
    int userAvgPeriodLength,
    int userCyclesTracked,
    PopulationCycleData populationData,
  ) {
    // Calculate confidence based on sample size
    // More tracked cycles = higher confidence in user data
    final userConfidence = (userCyclesTracked / 12).clamp(0.0, 1.0);
    final populationConfidence = populationData.sampleSize > 1000 ? 0.95 : 0.70;
    final combinedConfidence = (userConfidence + populationConfidence) / 2;

    final cycleVariance = userAvgCycleLength - populationData.averageCycleLength;
    final periodVariance = userAvgPeriodLength - populationData.averagePeriodLength;

    // Generate interpretation based on variance
    String interpretation = _generateInterpretation(
      cycleVariance,
      periodVariance,
      populationData.stdDevCycleLength,
    );

    return CycleComparison(
      userCycleLength: userAvgCycleLength.toDouble(),
      populationCycleLength: populationData.averageCycleLength,
      cycleVariance: cycleVariance,
      userPeriodLength: userAvgPeriodLength.toDouble(),
      populationPeriodLength: populationData.averagePeriodLength,
      periodVariance: periodVariance,
      interpretation: interpretation,
      confidence: combinedConfidence,
    );
  }

  /// Generate user-friendly interpretation of cycle comparison
  String _generateInterpretation(
    double cycleVariance,
    double periodVariance,
    double stdDev,
  ) {
    // Calculate Z-score for proper statistical comparison
    final zScore = cycleVariance / stdDev;
    final absZScore = zScore.abs();
    
    if (absZScore > 2.0) {
      // Beyond 2 standard deviations - significant outlier
      if (cycleVariance > 0) {
        return 'Your cycle is significantly longer than average (${zScore.toStringAsFixed(2)} standard deviations). This is outside typical range and may warrant medical consultation.';
      } else {
        return 'Your cycle is significantly shorter than average (${zScore.toStringAsFixed(2)} standard deviations). This is outside typical range and may warrant medical consultation.';
      }
    } else if (absZScore > 1.0) {
      // 1-2 standard deviations - moderate deviation
      if (cycleVariance > 0) {
        return 'Your cycle is moderately longer than typical (${zScore.toStringAsFixed(2)} standard deviations). While not in average range, this variation still occurs naturally in populations.';
      } else {
        return 'Your cycle is moderately shorter than typical (${zScore.toStringAsFixed(2)} standard deviations). While not in average range, this variation still occurs naturally in populations.';
      }
    } else {
      // Within 1 standard deviation - normal variation
      return 'Your cycle falls within normal healthy variation. This is typical and common in most populations.';
    }
  }

  /// Clear cached data
  void clearCache() {
    _cachedData = null;
    _cacheTime = null;
  }

  /// Get cached data or null if not available
  PopulationCycleData? getCachedData() => _cachedData;

  /// Get all PCOS symptoms dataset
  List<Map<String, dynamic>> getPcosSymptoms() {
    return PCOSMonitoringDatasets.pcosSymptoms;
  }

  /// Get PCOS symptoms by category
  List<Map<String, dynamic>> getSymptomsByCategory(String category) {
    return PCOSMonitoringDatasets.getSymptomsByCategory(category);
  }

  /// Get all treatment options
  List<Map<String, dynamic>> getTreatments() {
    return PCOSMonitoringDatasets.treatments;
  }

  /// Get treatments by type
  List<Map<String, dynamic>> getTreatmentsByType(String type) {
    return PCOSMonitoringDatasets.getTreatmentsByType(type);
  }

  /// Get lifestyle recommendations
  List<Map<String, dynamic>> getLifestyleRecommendations() {
    return PCOSMonitoringDatasets.lifestyleRecommendations;
  }

  /// Get recommendations by category
  List<Map<String, dynamic>> getRecommendationsByCategory(String category) {
    return PCOSMonitoringDatasets.getRecommendationsByCategory(category);
  }

  /// Get monitoring metrics for PCOS management
  List<Map<String, dynamic>> getMonitoringMetrics() {
    return PCOSMonitoringDatasets.monitoringMetrics;
  }

  /// Get health resources
  List<Map<String, dynamic>> getResources() {
    return PCOSMonitoringDatasets.resources;
  }

  /// Search resources by keyword
  List<Map<String, dynamic>> searchResources(String keyword) {
    return PCOSMonitoringDatasets.searchResources(keyword);
  }

  /// Get lab tests for PCOS diagnosis
  List<Map<String, dynamic>> getLabTests() {
    return PCOSMonitoringDatasets.labTests;
  }

  /// Get all datasets summary
  Map<String, dynamic> getAllDatasets() {
    return PCOSMonitoringDatasets.getAllDatasets();
  }
}
