# Kaggle API - Quick Reference Guide

## 1️⃣ Initial Setup (One-Time)

### Get Credentials
1. Go to https://www.kaggle.com/account
2. Scroll to "API" section
3. Click "Create New API Token"
4. You'll get `kaggle.json` with:
   - `username`: your Kaggle username
   - `key`: your API key

### Add Environment Variables

Create `.env` file in project root:
```env
KAGGLE_USERNAME=your_username
KAGGLE_KEY=your_api_key
```

## 2️⃣ Initialize in Your App

In `main.dart`:
```dart
import 'services/kaggle_data_service.dart';

void main() {
  // Initialize Kaggle service
  KaggleDataService.initialize();
  
  runApp(const OvaCareApp());
}
```

## 3️⃣ Use in Your Code

### Search for Datasets
```dart
// Search Kaggle for PCOS datasets
final datasets = await KaggleDataService.searchKaggleDatasets('PCOS');

// Get recommended PCOS datasets
final pcosDatasets = await KaggleDataService.getRecommendedPcosDatasets();
```

### Get Your Data
```dart
// Get symptoms
final symptoms = await KaggleDataService.getSymptomsDataset();

// Get treatments
final treatments = await KaggleDataService.getTreatmentsDataset();

// Get monitoring metrics
final metrics = await KaggleDataService.getMonitoringMetricsDataset();

// Get lab tests
final tests = await KaggleDataService.getLabTestsDataset();
```

### Export Data
```dart
// Export as JSON
final json = await KaggleDataService.exportDatasetAsJson('PCOS Symptoms Dataset');
```

### Check Status
```dart
// Check if Kaggle API is ready
if (KaggleDataService.isReady) {
  print('Kaggle API connected!');
} else {
  print('Using embedded datasets');
}

// Get status message
print(KaggleDataService.getStatus());
```

## 4️⃣ Common Operations

### Search by Keyword
```dart
final results = await KaggleDataService.searchDatasets('women health');
```

### Get All Available Datasets
```dart
final allDatasets = await KaggleDataService.getAvailableDatasets();

for (final dataset in allDatasets) {
  print('${dataset['name']}: ${dataset['records']} records');
}
```

### Verify Data
```dart
// Check data integrity
final isValid = await KaggleDataService.verifyDataIntegrity();

// Get accuracy report
final report = await KaggleDataService.getDataAccuracyReport();
```

## 5️⃣ Error Handling

```dart
try {
  final datasets = await KaggleDataService.searchKaggleDatasets('query');
} on KaggleApiException catch (e) {
  print('API Error: ${e.message}');
  print('Status Code: ${e.statusCode}');
  // App automatically falls back to embedded data
} catch (e) {
  print('Unexpected error: $e');
}
```

## 6️⃣ Cleanup

```dart
// Clean up when app closes
@override
void dispose() {
  KaggleDataService.dispose();
  super.dispose();
}
```

## 📊 Available Data

| Dataset | Method | Records |
|---------|--------|---------|
| PCOS Symptoms | `getSymptomsDataset()` | ~15,000 |
| Treatments | `getTreatmentsDataset()` | ~5,000 |
| Monitoring Metrics | `getMonitoringMetricsDataset()` | Varies |
| Lab Tests | `getLabTestsDataset()` | Varies |
| Resources | `getResourcesDataset()` | Varies |
| Lifestyle Tips | `getLifestyleRecommendationsDataset()` | Varies |

## ⚠️ Important Notes

- **Fallback**: If Kaggle API fails, app automatically uses embedded data
- **No Network**: App works offline with embedded datasets
- **Rate Limits**: 5 requests per 6 hours per dataset
- **Security**: Never commit credentials to git!
- **Best Practice**: Use environment variables for credentials

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Credentials not configured" | Set `KAGGLE_USERNAME` and `KAGGLE_KEY` env vars |
| "Authentication failed (401)" | Check credentials, regenerate API token |
| "Too many requests (429)" | Wait a few minutes, implement request queuing |
| Datasets not loading | Check internet, check if fallback data shows |

## 📝 Example: Complete Feature

```dart
class DatasetViewer extends StatefulWidget {
  @override
  State<DatasetViewer> createState() => _DatasetViewerState();
}

class _DatasetViewerState extends State<DatasetViewer> {
  late Future<List<Map<String, dynamic>>> _datasetsFuture;
  
  @override
  void initState() {
    super.initState();
    // Initialize Kaggle service
    KaggleDataService.initialize();
    // Load recommended PCOS datasets
    _datasetsFuture = KaggleDataService.getRecommendedPcosDatasets();
  }
  
  @override
  void dispose() {
    KaggleDataService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _datasetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        
        final datasets = snapshot.data ?? [];
        
        return ListView.builder(
          itemCount: datasets.length,
          itemBuilder: (context, index) {
            final dataset = datasets[index];
            return ListTile(
              title: Text(dataset['title'] ?? 'Unknown'),
              subtitle: Text(dataset['description'] ?? ''),
            );
          },
        );
      },
    );
  }
}
```

## 🔗 Links

- [Kaggle Account](https://www.kaggle.com/account)
- [Kaggle Datasets](https://www.kaggle.com/datasets)
- [Kaggle API Documentation](https://www.kaggle.com/api)
- [Full Setup Guide](./KAGGLE_SETUP.md)
- [Integration Summary](./KAGGLE_INTEGRATION_SUMMARY.md)

---

**Need more help?** Check KAGGLE_SETUP.md for detailed instructions.
