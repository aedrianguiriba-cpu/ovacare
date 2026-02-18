import 'dart:io';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

/// Service for generating and exporting health reports as PDF
class ReportService {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');
  static final DateFormat _fileNameFormat = DateFormat('yyyy-MM-dd_HHmmss');

  /// Generate Monthly Health Summary PDF
  static Future<File> generateMonthlyHealthSummary({
    required List<Map<String, dynamic>> menstrualCycles,
    required List<Map<String, dynamic>> symptoms,
    required List<Map<String, dynamic>> weightEntries,
    required List<Map<String, dynamic>> hydrationEntries,
    required Map<String, dynamic> riskAssessment,
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthName = DateFormat('MMMM yyyy').format(now);

    // Filter data for current month with null safety
    final monthlyCycles = menstrualCycles.where((c) {
      final start = c['start'] as DateTime?;
      if (start == null) return false;
      return start.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          start.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    final monthlySymptoms = symptoms.where((s) {
      final date = s['date'] as DateTime?;
      if (date == null) return false;
      return date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          date.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    final monthlyWeight = weightEntries.where((w) {
      final date = w['date'] as DateTime?;
      if (date == null) return false;
      return date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          date.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    final monthlyHydration = hydrationEntries.where((h) {
      final date = h['date'] as DateTime?;
      if (date == null) return false;
      return date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          date.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader('Monthly Health Summary', monthName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSectionTitle('Overview'),
          pw.SizedBox(height: 10),
          _buildOverviewStats(
            periods: monthlyCycles.length,
            symptomsLogged: monthlySymptoms.length,
            weightEntries: monthlyWeight.length,
            hydrationDays: monthlyHydration.length,
          ),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Menstrual Cycle'),
          pw.SizedBox(height: 10),
          if (monthlyCycles.isEmpty)
            pw.Text('No periods recorded this month.', style: const pw.TextStyle(fontSize: 12))
          else
            ...monthlyCycles.map((c) => _buildCycleEntry(c)),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Symptoms Summary'),
          pw.SizedBox(height: 10),
          if (monthlySymptoms.isEmpty)
            pw.Text('No symptoms logged this month.', style: const pw.TextStyle(fontSize: 12))
          else
            _buildSymptomsSummary(monthlySymptoms),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Weight Tracking'),
          pw.SizedBox(height: 10),
          if (monthlyWeight.isEmpty)
            pw.Text('No weight entries this month.', style: const pw.TextStyle(fontSize: 12))
          else
            _buildWeightSummary(monthlyWeight),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Risk Assessment'),
          pw.SizedBox(height: 10),
          _buildRiskAssessment(riskAssessment),
        ],
      ),
    );

    return _saveDocument(pdf, 'monthly_health_summary');
  }

  /// Generate Cycle Analysis Report PDF
  static Future<File> generateCycleAnalysisReport({
    required List<Map<String, dynamic>> menstrualCycles,
    required DateTime? nextPrediction,
    required int? daysUntilNext,
  }) async {
    final pdf = pw.Document();

    // Calculate cycle statistics with null safety
    final cycleLengths = <int>[];
    final periodLengths = <int>[];
    
    for (int i = 0; i < menstrualCycles.length; i++) {
      final cycle = menstrualCycles[i];
      final start = cycle['start'] as DateTime?;
      final end = cycle['end'] as DateTime?;
      if (start == null || end == null) continue;
      periodLengths.add(end.difference(start).inDays + 1);
      
      if (i < menstrualCycles.length - 1) {
        final nextCycle = menstrualCycles[i + 1];
        final nextStart = nextCycle['start'] as DateTime?;
        if (nextStart == null) continue;
        final length = start.difference(nextStart).inDays.abs();
        if (length > 0 && length < 100) {
          cycleLengths.add(length);
        }
      }
    }

    final avgCycleLength = cycleLengths.isEmpty 
        ? 28.0 
        : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    final avgPeriodLength = periodLengths.isEmpty 
        ? 5.0 
        : periodLengths.reduce((a, b) => a + b) / periodLengths.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader('Cycle Analysis Report', _dateFormat.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSectionTitle('Cycle Statistics'),
          pw.SizedBox(height: 10),
          _buildStatsRow([
            {'label': 'Total Cycles Tracked', 'value': '${menstrualCycles.length}'},
            {'label': 'Average Cycle Length', 'value': '${avgCycleLength.toStringAsFixed(1)} days'},
            {'label': 'Average Period Length', 'value': '${avgPeriodLength.toStringAsFixed(1)} days'},
          ]),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Cycle Prediction'),
          pw.SizedBox(height: 10),
          if (nextPrediction != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.pink50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Next Period Predicted:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text(_dateFormat.format(nextPrediction), style: const pw.TextStyle(fontSize: 16)),
                  if (daysUntilNext != null)
                    pw.Text('($daysUntilNext days from today)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            )
          else
            pw.Text('Not enough data for prediction. Log more cycles.', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Cycle History'),
          pw.SizedBox(height: 10),
          if (menstrualCycles.isEmpty)
            pw.Text('No cycles recorded yet.', style: const pw.TextStyle(fontSize: 12))
          else
            _buildCycleHistoryTable(menstrualCycles.take(12).toList(), cycleLengths),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Cycle Length Variation'),
          pw.SizedBox(height: 10),
          _buildCycleLengthAnalysis(cycleLengths, avgCycleLength),
        ],
      ),
    );

    return _saveDocument(pdf, 'cycle_analysis_report');
  }

  /// Generate Symptom Tracking Report PDF
  static Future<File> generateSymptomTrackingReport({
    required List<Map<String, dynamic>> symptoms,
  }) async {
    final pdf = pw.Document();

    // Analyze symptoms by type
    final symptomCounts = <String, int>{};
    final symptomSeverities = <String, List<int>>{};
    
    for (final symptom in symptoms) {
      final name = symptom['symptom'] as String? ?? 'Unknown';
      final severity = symptom['severity'] as int? ?? 3;
      
      symptomCounts[name] = (symptomCounts[name] ?? 0) + 1;
      symptomSeverities.putIfAbsent(name, () => []).add(severity);
    }

    final sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader('Symptom Tracking Report', _dateFormat.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSectionTitle('Overview'),
          pw.SizedBox(height: 10),
          pw.Text('Total symptoms logged: ${symptoms.length}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('Unique symptom types: ${symptomCounts.length}', style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Most Frequent Symptoms'),
          pw.SizedBox(height: 10),
          if (sortedSymptoms.isEmpty)
            pw.Text('No symptoms logged yet.', style: const pw.TextStyle(fontSize: 12))
          else
            ...sortedSymptoms.take(10).map((entry) {
              final avgSeverity = symptomSeverities[entry.key]!.reduce((a, b) => a + b) / symptomSeverities[entry.key]!.length;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _getSeverityColor(avgSeverity),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Text('${entry.value}x', style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(width: 20),
                    pw.Text('Avg severity: ${avgSeverity.toStringAsFixed(1)}/5', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Recent Symptom Log'),
          pw.SizedBox(height: 10),
          if (symptoms.isEmpty)
            pw.Text('No symptoms logged.', style: const pw.TextStyle(fontSize: 12))
          else
            _buildRecentSymptomsTable(symptoms.take(15).toList()),
        ],
      ),
    );

    return _saveDocument(pdf, 'symptom_tracking_report');
  }

  /// Generate Risk Assessment Report PDF
  static Future<File> generateRiskAssessmentReport({
    required Map<String, dynamic> riskAssessment,
    required List<Map<String, dynamic>> menstrualCycles,
    required List<Map<String, dynamic>> symptoms,
    required List<Map<String, dynamic>> weightEntries,
  }) async {
    final pdf = pw.Document();

    final factors = (riskAssessment['factors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final riskLevel = riskAssessment['pcosRisk'] as String? ?? 'Unknown';
    final score = riskAssessment['score'] as num? ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader('PCOS Risk Assessment Report', _dateFormat.format(DateTime.now())),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSectionTitle('Overall Assessment'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _getRiskColor(riskLevel),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              children: [
                pw.Text('Risk Level: $riskLevel', 
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Score: ${score.toStringAsFixed(0)}/100', 
                    style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Risk Factors Analysis'),
          pw.SizedBox(height: 10),
          if (factors.isEmpty)
            pw.Text('Not enough data to assess risk factors. Continue tracking your health metrics.', 
                style: const pw.TextStyle(fontSize: 12))
          else
            ...factors.map((factor) => _buildFactorCard(factor)),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Data Summary'),
          pw.SizedBox(height: 10),
          _buildStatsRow([
            {'label': 'Cycles Tracked', 'value': '${menstrualCycles.length}'},
            {'label': 'Symptoms Logged', 'value': '${symptoms.length}'},
            {'label': 'Weight Entries', 'value': '${weightEntries.length}'},
          ]),
          pw.SizedBox(height: 20),

          _buildSectionTitle('Disclaimer'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.yellow50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.yellow700),
            ),
            child: pw.Text(
              'This report is for informational purposes only and should not be used as a substitute for professional medical advice, diagnosis, or treatment. Please consult with a healthcare provider for proper evaluation and guidance.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            ),
          ),
        ],
      ),
    );

    return _saveDocument(pdf, 'risk_assessment_report');
  }

  // ============== Helper Methods ==============

  static pw.Widget _buildHeader(String title, String subtitle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('OvaCare', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text('Health Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.pink200),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: ${_dateTimeFormat.format(DateTime.now())}', 
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', 
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.pink50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.pink800)),
    );
  }

  static pw.Widget _buildOverviewStats({
    required int periods,
    required int symptomsLogged,
    required int weightEntries,
    required int hydrationDays,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildStatBox('Periods', '$periods'),
        _buildStatBox('Symptoms', '$symptomsLogged'),
        _buildStatBox('Weight Logs', '$weightEntries'),
        _buildStatBox('Hydration', '$hydrationDays days'),
      ],
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildCycleEntry(Map<String, dynamic> cycle) {
    final start = cycle['start'] as DateTime?;
    final end = cycle['end'] as DateTime?;
    if (start == null || end == null) {
      return pw.Container();
    }
    final flow = cycle['flow'] as int? ?? 3;
    final length = end.difference(start).inDays + 1;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('${_dateFormat.format(start)} - ${_dateFormat.format(end)}'),
          pw.Text('$length days', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Flow: $flow/5', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildSymptomsSummary(List<Map<String, dynamic>> symptoms) {
    final counts = <String, int>{};
    for (final s in symptoms) {
      final name = s['symptom'] as String? ?? 'Unknown';
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Total logged: ${symptoms.length}', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 8),
        ...sorted.take(5).map((e) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.Container(width: 8, height: 8, decoration: const pw.BoxDecoration(color: PdfColors.pink, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 8),
              pw.Text('${e.key}: ${e.value}x', style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        )),
      ],
    );
  }

  static pw.Widget _buildWeightSummary(List<Map<String, dynamic>> weights) {
    if (weights.isEmpty) return pw.Text('No data');
    
    final values = weights
        .where((w) => w['weight'] != null)
        .map((w) => (w['weight'] as num).toDouble())
        .toList();
    if (values.isEmpty) return pw.Text('No valid weight data');
    
    final latest = values.first;
    final oldest = values.last;
    final change = latest - oldest;
    final avg = values.reduce((a, b) => a + b) / values.length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Latest: ${latest.toStringAsFixed(1)} kg', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text('Average: ${avg.toStringAsFixed(1)} kg', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Change: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg', 
            style: pw.TextStyle(fontSize: 12, color: change >= 0 ? PdfColors.green : PdfColors.red)),
      ],
    );
  }

  static pw.Widget _buildRiskAssessment(Map<String, dynamic> risk) {
    final level = risk['pcosRisk'] as String? ?? 'Unknown';
    final score = risk['score'] as num? ?? 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: _getRiskColor(level),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Current Risk Level: $level', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Score: ${score.toStringAsFixed(0)}/100', style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildStatsRow(List<Map<String, String>> stats) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: stats.map((s) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            pw.Text(s['value']!, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(s['label']!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
      )).toList(),
    );
  }

  static pw.Widget _buildCycleHistoryTable(List<Map<String, dynamic>> cycles, List<int> lengths) {
    // Filter out cycles with null dates
    final validCycles = cycles.where((c) => c['start'] != null && c['end'] != null).toList();
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.pink50),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Start Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('End Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Period Length', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Cycle Length', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          ],
        ),
        ...validCycles.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final start = c['start'] as DateTime;
          final end = c['end'] as DateTime;
          final periodLen = end.difference(start).inDays + 1;
          final cycleLen = i < lengths.length ? '${lengths[i]} days' : '-';

          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_dateFormat.format(start), style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_dateFormat.format(end), style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$periodLen days', style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(cycleLen, style: const pw.TextStyle(fontSize: 10))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildCycleLengthAnalysis(List<int> lengths, double avg) {
    if (lengths.isEmpty) {
      return pw.Text('Not enough cycles to analyze variation.', style: const pw.TextStyle(fontSize: 12));
    }

    final min = lengths.reduce((a, b) => a < b ? a : b);
    final max = lengths.reduce((a, b) => a > b ? a : b);
    final variance = lengths.map((l) => (l - avg) * (l - avg)).reduce((a, b) => a + b) / lengths.length;
    final stdDev = math.sqrt(variance);

    String regularity = 'Regular';
    if (stdDev > 10) {
      regularity = 'Irregular';
    } else if (stdDev > 5) {
      regularity = 'Somewhat Variable';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Shortest cycle: $min days', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Longest cycle: $max days', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Variation: ±${stdDev.toStringAsFixed(1)} days', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: regularity == 'Regular' ? PdfColors.green50 : (regularity == 'Irregular' ? PdfColors.red50 : PdfColors.yellow50),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text('Assessment: $regularity cycles', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.Widget _buildRecentSymptomsTable(List<Map<String, dynamic>> symptoms) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.pink50),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Symptom', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Severity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          ],
        ),
        ...symptoms.map((s) {
          final date = s['date'] as DateTime?;
          final name = s['symptom'] as String? ?? 'Unknown';
          final severity = s['severity'] as int? ?? 3;

          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(date != null ? _dateFormat.format(date) : '-', style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name, style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$severity/5', style: const pw.TextStyle(fontSize: 10))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFactorCard(Map<String, dynamic> factor) {
    final name = factor['name'] as String? ?? 'Unknown';
    final severity = factor['severity'] as String? ?? 'Low';
    final description = factor['description'] as String? ?? '';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: severity == 'High' ? PdfColors.red50 : (severity == 'Moderate' ? PdfColors.yellow50 : PdfColors.green50),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: severity == 'High' ? PdfColors.red300 : (severity == 'Moderate' ? PdfColors.yellow300 : PdfColors.green300),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: severity == 'High' ? PdfColors.red200 : (severity == 'Moderate' ? PdfColors.yellow200 : PdfColors.green200),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(severity, style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(description.replaceAll(RegExp(r'[^\x00-\x7F]+'), ''), style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static PdfColor _getSeverityColor(double severity) {
    if (severity >= 4) return PdfColors.red50;
    if (severity >= 3) return PdfColors.orange50;
    return PdfColors.green50;
  }

  static PdfColor _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return PdfColors.red50;
      case 'moderate':
        return PdfColors.yellow50;
      case 'low':
        return PdfColors.green50;
      default:
        return PdfColors.grey100;
    }
  }

  static Future<File> _saveDocument(pw.Document pdf, String baseName) async {
    final output = await getApplicationDocumentsDirectory();
    final fileName = '${baseName}_${_fileNameFormat.format(DateTime.now())}.pdf';
    final separator = Platform.isWindows ? '\\' : '/';
    final file = File('${output.path}$separator$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Open PDF file
  static Future<void> openPdf(File file) async {
    await OpenFilex.open(file.path);
  }

  /// Share PDF file
  static Future<void> sharePdf(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'OvaCare Health Report',
      text: 'My health report from OvaCare app',
    );
  }
}
