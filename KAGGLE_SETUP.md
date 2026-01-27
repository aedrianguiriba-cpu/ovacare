# Kaggle API Setup Instructions

## Overview
The OvaCare app uses the Kaggle API to fetch health-related datasets for PCOS monitoring and management.

## Prerequisites
- Kaggle account (create at https://www.kaggle.com)
- Internet connection

## Step 1: Get Your Kaggle API Credentials

1. Log in to [Kaggle.com](https://www.kaggle.com)
2. Go to your **Account Settings** (click your profile → Account)
3. Scroll to the **API** section
4. Click **"Create New API Token"**
   - This downloads a `kaggle.json` file to your Downloads folder
5. Extract the credentials from `kaggle.json`:
   ```json
   {
     "username": "your_username",
     "key": "your_api_key"
   }
   ```

## Step 2: Configure Environment Variables

### For Development (Local)

Create a `.env` file in the project root (`d:\Documents\web\ovacare\`):

```env
KAGGLE_USERNAME=your_username
KAGGLE_KEY=your_api_key
```

### For Flutter Desktop/Mobile Apps

Add to your app initialization in `main.dart`:

```dart
import 'dart:io';

void main() {
  // Load from environment
  Platform.environment['KAGGLE_USERNAME'];
  Platform.environment['KAGGLE_KEY'];
  
  runApp(const OvaCareApp());
}
```

### For Web Apps

For web deployment, use secure storage methods (not environment variables):

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();

// Save credentials
await storage.write(
  key: 'kaggle_username',
  value: 'your_username',
);

await storage.write(
  key: 'kaggle_key',
  value: 'your_api_key',
);

// Retrieve credentials
final username = await storage.read(key: 'kaggle_username');
final apiKey = await storage.read(key: 'kaggle_key');
```

## Step 3: Initialize the Service

In your app's main entry point or initialization module:

```dart
import 'package:ovacare/services/kaggle_data_service.dart';

void main() {
  // Initialize Kaggle Data Service
  KaggleDataService.initialize();
  
  // Check if service is ready
  if (KaggleDataService.isReady) {
    print('Kaggle API is configured and ready');
  } else {
    print('Kaggle API fallback: using embedded datasets');
  }
  
  runApp(const OvaCareApp());
}
```

## Step 4: Use the Service

```dart
// Search for PCOS datasets
final pcosDatasets = await KaggleDataService.getRecommendedPcosDatasets();

// Search for specific datasets
final results = await KaggleDataService.searchKaggleDatasets('women health');

// Get available datasets
final allDatasets = await KaggleDataService.getAvailableDatasets();

// Get specific dataset
final symptoms = await KaggleDataService.getSymptomsDataset();
```

## Troubleshooting

### "Kaggle API credentials not configured"
- Ensure `KAGGLE_USERNAME` and `KAGGLE_KEY` environment variables are set
- Verify the credentials in your `kaggle.json` file are correct

### "Authentication failed (401)"
- Double-check username and API key spelling
- Regenerate your API token in Kaggle settings
- Ensure the API token hasn't expired

### "Too many requests (429)"
- You've hit the Kaggle API rate limit
- Wait a few minutes before trying again
- The app automatically falls back to embedded datasets

### No internet connection
- The app gracefully falls back to embedded PCOS datasets
- All core features work without Kaggle API

## API Limits

- **Rate Limit**: 5 requests per 6 hours per dataset
- **Dataset Size**: Up to 20GB per download
- **Concurrent Downloads**: 1 at a time

## Security Best Practices

✅ **DO:**
- Store credentials in environment variables
- Use secure storage for sensitive data
- Never commit `.env` files to version control
- Rotate API tokens regularly

❌ **DON'T:**
- Hardcode credentials in source code
- Commit `kaggle.json` to git
- Share your API key in public repositories
- Use the same API key across multiple apps

## Available Datasets

The app searches for and integrates these dataset types:

1. **PCOS Datasets** - Symptoms, treatments, and monitoring metrics
2. **Women Health Tracking** - Cycle tracking and health metrics
3. **Menstrual Cycle Data** - Period tracking information
4. **Fertility Tracking** - Reproductive health data
5. **Lab Test Data** - Essential diagnostic tests

## Fallback Behavior

If Kaggle API is unavailable, the app automatically uses embedded datasets:
- PCOS Symptoms (8 common symptoms)
- Treatments (6 treatment categories)
- Monitoring Metrics (7 metrics)
- Lab Tests (6 essential tests)

## Additional Resources

- [Kaggle API Documentation](https://www.kaggle.com/api)
- [Kaggle Datasets Explorer](https://www.kaggle.com/datasets)
- [Kaggle API GitHub](https://github.com/Kaggle/Kaggle-api)

## Support

If you encounter issues:

1. Check the console logs for detailed error messages
2. Verify your credentials with the Kaggle website
3. Test API access using the Kaggle CLI: `kaggle datasets list`
4. Review the error messages in `KaggleApiException`
