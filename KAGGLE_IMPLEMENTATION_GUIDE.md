# Kaggle API Integration - Implementation Guide

## 📋 Overview

This guide walks you through the complete Kaggle API integration for the OvaCare Flutter application. The integration provides access to health datasets with automatic fallback to embedded data.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OvaCare Flutter App                       │
│                        (main.dart)                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   KaggleDataService                │
        │  (services/kaggle_data_service.dart)
        │                                     │
        │  - High-level data operations       │
        │  - Automatic fallback handling      │
        │  - Search & filter                  │
        └────────────────┬────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   KaggleApiClient                  │
        │  (api/kaggle_api_client.dart)      │
        │                                     │
        │  - HTTP communication               │
        │  - Authentication                   │
        │  - Error handling                   │
        └────────────────┬────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   KaggleConfig                     │
        │  (config/kaggle_config.dart)       │
        │                                     │
        │  - Credential management            │
        │  - Configuration validation         │
        └────────────────┬────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Environment Variables            │
        │   (KAGGLE_USERNAME, KAGGLE_KEY)    │
        └────────────────────────────────────┘
```

## 📁 File Structure

```
ovacare/
├── lib/
│   ├── api/
│   │   └── kaggle_api_client.dart          ← API Client
│   ├── config/
│   │   └── kaggle_config.dart              ← Configuration
│   ├── services/
│   │   └── kaggle_data_service.dart        ← Data Service
│   ├── main.dart                           ← App Entry Point
│   └── pcos_datasets.dart                  ← Embedded Data
│
├── test/
│   └── kaggle_integration_test.dart        ← Tests
│
├── KAGGLE_SETUP.md                         ← Detailed Setup
├── KAGGLE_QUICK_START.md                   ← Quick Reference
├── KAGGLE_INTEGRATION_SUMMARY.md           ← Summary
├── .env.example                            ← Environment Template
└── .gitignore.kaggle                       ← Security Settings
```

## 🔧 Component Details

### 1. Configuration (`lib/config/kaggle_config.dart`)

**Responsibility**: Manage credentials and configuration

**Key Features**:
- Environment variable support
- Credential validation
- Clear error messages

**Usage**:
```dart
// Check if configured
if (KaggleConfig.isConfigured) {
  print('Ready to use Kaggle API');
}

// Validate configuration
KaggleConfig.validate(); // Throws exception if not configured

// Get status
String status = KaggleConfig.getConfigStatus();
```

### 2. API Client (`lib/api/kaggle_api_client.dart`)

**Responsibility**: Handle HTTP communication with Kaggle API

**Key Methods**:
- `listDatasets()` - List available datasets
- `getDataset()` - Get dataset details
- `searchDatasets()` - Search for datasets
- `downloadDataset()` - Download dataset file
- `getApiUsage()` - Get API usage info

**Features**:
- Automatic Basic Auth header
- Connection timeout management (30 seconds)
- Comprehensive error handling
- Rate limit detection

**Usage**:
```dart
final client = KaggleApiClient();

// List datasets
final datasets = await client.listDatasets(
  query: 'PCOS',
  sortBy: 'hotness',
  pageSize: 20,
);

// Get specific dataset
final dataset = await client.getDataset('owner/dataset-name');

// Close when done
client.close();
```

### 3. Data Service (`lib/services/kaggle_data_service.dart`)

**Responsibility**: Provide high-level data operations

**Key Methods**:
- `initialize()` - Initialize service
- `searchKaggleDatasets()` - Search Kaggle
- `getRecommendedPcosDatasets()` - Get PCOS datasets
- `getAvailableDatasets()` - Get all datasets
- `getSymptomsDataset()` - Get symptoms
- `getTreatmentsDataset()` - Get treatments
- And more...

**Features**:
- Automatic fallback to embedded data
- Service initialization & cleanup
- Status checking
- Data export & validation

**Usage**:
```dart
// Initialize
KaggleDataService.initialize();

// Use service
final datasets = await KaggleDataService.getRecommendedPcosDatasets();

// Check status
if (KaggleDataService.isReady) {
  print('Connected to Kaggle API');
}

// Cleanup
KaggleDataService.dispose();
```

## 🚀 Initialization Flow

1. **App Startup** → `main.dart` calls `KaggleDataService.initialize()`
2. **Initialization** → Service creates `KaggleApiClient`
3. **Config Validation** → Client validates `KaggleConfig` credentials
4. **Ready to Use** → Service is ready for data operations
5. **Fallback Ready** → If API fails, uses embedded data automatically

## 🔐 Security Implementation

### Credential Protection

1. **Never Hardcoded**: Credentials stored in environment variables only
2. **No Logging**: Credentials never printed to console
3. **Version Control Safe**: `.env` files excluded from git
4. **Secure Transport**: HTTPS/Basic Auth for API communication

### Best Practices

```dart
// ✅ GOOD - Use environment variables
static const String username = String.fromEnvironment('KAGGLE_USERNAME');

// ❌ BAD - Never hardcode
static const String username = 'actual_username';

// ❌ BAD - Never log credentials
print('API Key: $apiKey'); // NEVER!

// ✅ GOOD - Log only status
print('Kaggle API initialized');
```

## 🔄 Error Handling Flow

```
Request Made
     │
     ▼
[Success (200)] ──→ Return Data
     │
     ├─→ [Auth Failed (401)] ──→ Log Error → Fallback Data
     │
     ├─→ [Rate Limited (429)] ──→ Log Error → Fallback Data
     │
     ├─→ [Connection Error] ──→ Log Error → Fallback Data
     │
     └─→ [Other Error] ──→ Log Error → Fallback Data
     
All Errors → Automatic Fallback to Embedded Data
```

## 📊 Data Flow Example

```dart
// 1. Initialize
KaggleDataService.initialize();

// 2. Call method
var datasets = await KaggleDataService.searchKaggleDatasets('PCOS');

// 3. Data Flow:
//    ├─ Check if ready
//    ├─ Call API
//    ├─ Parse response
//    ├─ Return data
//    └─ OR fallback on error

// 4. Use data
for (var dataset in datasets) {
  print('${dataset['title']}: ${dataset['downloads']} downloads');
}
```

## 🧪 Testing Strategy

```dart
// Run integration tests
flutter test test/kaggle_integration_test.dart

// Run specific test
flutter test test/kaggle_integration_test.dart -n "Service initializes"

// Run with coverage
flutter test --coverage test/kaggle_integration_test.dart
```

**Test Coverage**:
- Configuration validation
- Service initialization
- Error handling
- Fallback mechanisms
- Data integrity
- Export functionality
- Data accuracy reports

## 🐛 Debugging Tips

### 1. Check Configuration
```dart
print(KaggleConfig.getConfigStatus());
print('Configured: ${KaggleConfig.isConfigured}');
```

### 2. Check Service Status
```dart
print('Service Ready: ${KaggleDataService.isReady}');
print('Status: ${KaggleDataService.getStatus()}');
```

### 3. Enable Logging
```dart
// Add to main.dart
if (KaggleDataService.isReady) {
  print('✅ Kaggle API connected');
} else {
  print('⚠️ Using embedded datasets');
}
```

### 4. Test API Directly
```dart
try {
  final client = KaggleApiClient();
  final datasets = await client.listDatasets(pageSize: 5);
  print('API works! Found ${datasets.length} datasets');
} on KaggleApiException catch (e) {
  print('API Error: ${e.message}');
}
```

## 🔄 Lifecycle Management

### Initialization
```dart
void main() {
  KaggleDataService.initialize(); // One time
  runApp(const OvaCareApp());
}
```

### During Runtime
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // Service already initialized in main.dart
    // Just use it
  }
  
  // Use KaggleDataService methods
}
```

### Cleanup
```dart
@override
void dispose() {
  // If you need to clean up
  // KaggleDataService.dispose(); // Only if needed
  super.dispose();
}
```

## 📈 Performance Considerations

### Timeouts
```dart
// Default: 30 seconds per request
// Configurable in KaggleConfig
static const Duration timeout = Duration(seconds: 30);
```

### Caching
Consider implementing local caching:
```dart
// Example: Cache datasets
final cache = <String, List<Map<String, dynamic>>>{};

Future<List<Map<String, dynamic>>> getCachedDatasets() async {
  if (cache.containsKey('pcos')) {
    return cache['pcos']!;
  }
  
  final data = await KaggleDataService.getRecommendedPcosDatasets();
  cache['pcos'] = data;
  return data;
}
```

### Pagination
For large result sets:
```dart
// List with pagination
final page1 = await KaggleDataService.listKaggleDatasets(
  page: 1,
);

final page2 = await KaggleDataService.listKaggleDatasets(
  page: 2,
);
```

## 🚨 Common Issues & Solutions

### Issue: "Credentials not configured"
```
Cause: Environment variables not set
Solution: Set KAGGLE_USERNAME and KAGGLE_KEY
```

### Issue: "Authentication failed"
```
Cause: Invalid credentials
Solution: 
1. Verify credentials in kaggle.json
2. Regenerate API token at kaggle.com/account
3. Update environment variables
```

### Issue: "Too many requests"
```
Cause: Rate limit exceeded (5 requests per 6 hours)
Solution: 
1. Wait a few minutes
2. Implement request queuing
3. Cache results locally
```

### Issue: Network timeout
```
Cause: Slow connection or Kaggle server slow
Solution:
1. Increase timeout in KaggleConfig
2. App automatically falls back to embedded data
3. Retry with exponential backoff
```

## 📚 Additional Resources

- [Kaggle API Documentation](https://www.kaggle.com/api)
- [Kaggle Datasets](https://www.kaggle.com/datasets)
- [Kaggle Python API](https://github.com/Kaggle/kaggle-api)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Environment Variables in Flutter](https://dart.dev/guides/libraries/private-files)

## ✅ Checklist for Integration

- [ ] Created `lib/api/kaggle_api_client.dart`
- [ ] Created `lib/config/kaggle_config.dart`
- [ ] Created `lib/services/kaggle_data_service.dart`
- [ ] Updated `lib/main.dart` with initialization
- [ ] Created `.env.example` template
- [ ] Set up environment variables
- [ ] Ran integration tests
- [ ] Tested with valid credentials
- [ ] Tested fallback behavior (no credentials)
- [ ] Added to `.gitignore` (credentials)
- [ ] Documented in code comments
- [ ] Ready for production deployment

---

**Status**: ✅ Complete Implementation

**Next Step**: Follow [KAGGLE_QUICK_START.md](./KAGGLE_QUICK_START.md) to start using the API!
