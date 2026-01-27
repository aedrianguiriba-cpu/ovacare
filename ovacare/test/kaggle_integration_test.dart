import 'package:flutter_test/flutter_test.dart';
import 'package:ovacare/config/kaggle_config.dart';
import 'package:ovacare/config/kaggle_config_provider.dart';
import 'package:ovacare/api/kaggle_api_client.dart';
import 'package:ovacare/services/kaggle_data_service.dart';

void main() {
  setUpAll(() async {
    // Set test credentials using the config provider
    // This is much simpler than trying to load .env files in tests
    KaggleConfigProvider.setTestCredentials(
      'aedrianguiriba',
      '8ef7c261ffb0d4fdbacd45850a9b59f6',
    );
    
    print('✓ Test credentials set');
    print('  Username: ${KaggleConfig.username}');
    print('  API Key: ${KaggleConfig.apiKey}');
  });

  tearDownAll(() {
    // Clear test credentials after tests
    KaggleConfigProvider.clearTestCredentials();
  });

  group('Kaggle API Configuration Tests - Without Credentials', () {
    setUp(() {
      // Clear credentials for these tests
      KaggleConfigProvider.clearTestCredentials();
    });

    test('KaggleConfig validation fails when not configured', () {
      expect(
        () => KaggleConfig.validate(),
        throwsA(isA<KaggleConfigException>()),
      );
    });

    test('KaggleConfig.isConfigured returns false without credentials', () {
      expect(KaggleConfig.isConfigured, false);
    });

    test('KaggleConfig.getConfigStatus returns appropriate message', () {
      final status = KaggleConfig.getConfigStatus();
      expect(status.contains('not configured'), true);
    });
  });

  group('Kaggle API Configuration Tests - With Credentials', () {
    setUp(() {
      // Set test credentials for these tests
      KaggleConfigProvider.setTestCredentials(
        'aedrianguiriba',
        '8ef7c261ffb0d4fdbacd45850a9b59f6',
      );
    });

    test('KaggleConfig.isConfigured returns true with credentials', () {
      expect(KaggleConfig.isConfigured, true);
    });

    test('KaggleConfig.getConfigStatus returns success message', () {
      final status = KaggleConfig.getConfigStatus();
      expect(status.contains('ready'), true);
    });
  });

  group('Kaggle Data Service Tests', () {
    setUp(() {
      // Initialize before each test
      KaggleDataService.initialize();
    });

    tearDown(() {
      // Clean up after each test
      KaggleDataService.dispose();
    });

    test('Service initializes without errors', () {
      expect(KaggleDataService.getStatus(), isNotNull);
    });

    test('Service provides fallback to embedded datasets', () async {
      final datasets = await KaggleDataService.getAvailableDatasets();
      expect(datasets, isNotEmpty);
      expect(datasets[0].containsKey('name'), true);
    });

    test('Search datasets returns list', () async {
      final results = await KaggleDataService.searchDatasets('PCOS');
      expect(results, isA<List>());
    });

    test('Get symptoms dataset returns data', () async {
      final symptoms = await KaggleDataService.getSymptomsDataset();
      expect(symptoms, isNotEmpty);
    });

    test('Verify data integrity passes for embedded data', () async {
      final isValid = await KaggleDataService.verifyDataIntegrity();
      expect(isValid, true);
    });

    test('Export dataset as JSON works', () async {
      final json =
          await KaggleDataService.exportDatasetAsJson('PCOS Symptoms Dataset');
      expect(json, contains('PCOS Symptoms Dataset'));
    });

    test('Get data accuracy report returns valid data', () async {
      final report = await KaggleDataService.getDataAccuracyReport();
      expect(report.containsKey('report_title'), true);
      expect(report.containsKey('generated_at'), true);
      expect(report.containsKey('all_datasets_validated'), true);
    });
  });

  group('Kaggle API Client Error Handling', () {
    test('KaggleApiException formats message correctly', () {
      final exception = KaggleApiException(
        message: 'Test error',
        statusCode: 401,
      );
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('Status: 401'));
    });

    test('KaggleApiException with empty message', () {
      final exception = KaggleApiException(message: '');
      expect(exception.toString(), contains('KaggleApiException'));
    });
  });

  group('Data Accuracy Tests', () {
    test('Data accuracy report has all required fields', () async {
      KaggleDataService.initialize();
      final report = await KaggleDataService.getDataAccuracyReport();

      expect(report.containsKey('report_title'), true);
      expect(report.containsKey('generated_at'), true);
      expect(report.containsKey('all_datasets_validated'), true);
      expect(report.containsKey('datasets'), true);
      expect(report.containsKey('summary'), true);

      KaggleDataService.dispose();
    });

    test('Dataset validation returns required metadata', () async {
      KaggleDataService.initialize();
      final report = await KaggleDataService.getDataAccuracyReport();
      final datasets = report['datasets'] as Map<String, dynamic>;

      expect(datasets.isNotEmpty, true);

      KaggleDataService.dispose();
    });
  });
}
