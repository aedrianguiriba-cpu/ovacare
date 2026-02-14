# Kaggle API Live - Method Reference Guide

## 🚀 Quick Method Reference

### 1. Initialize API (Recommended on App Start)
```dart
await KaggleDataService.initializeKaggleAPI()
```
**Returns:** `Map<String, dynamic>` with status
**Use Case:** Check API on startup, handle connection issues
**Output:** Detailed console log with emoji status

---

### 2. Get Recommended PCOS Datasets
```dart
await KaggleDataService.getRecommendedPcosDatasets()
```
**Returns:** `List<Map<String, dynamic>>` of datasets
**Use Case:** Load all PCOS-related datasets
**Features:** 
- Searches 4 categories in parallel
- Returns 20+ datasets
- Includes metadata (downloads, ratings, etc.)

**Response Example:**
```json
{
  "title": "Women's Health PCOS Dataset",
  "owner": "kaggle_user",
  "downloads": 1250,
  "usability": 4.8,
  "source": "Kaggle API (Live)",
  "url": "https://kaggle.com/datasets/..."
}
```

---

### 3. Search Datasets by Keyword
```dart
await KaggleDataService.searchKaggleDatasets('pcos+women')
```
**Returns:** `List<Map<String, dynamic>>` of matching datasets
**Use Case:** Find specific datasets
**Features:**
- Sorted by "hotness" (relevance)
- Returns up to 20 results
- Full metadata included

---

### 4. Get Dataset Details
```dart
await KaggleDataService.fetchKaggleDatasetDetails('janvi-reddy/pcos-data')
```
**Returns:** `Map<String, dynamic>?` with full dataset info
**Use Case:** Get detailed info about specific dataset
**Includes:**
- Dataset columns/fields
- Creation date
- Owner details
- File size
- Featured status

---

### 5. Get All Available Datasets
```dart
await KaggleDataService.getAvailableDatasets()
```
**Returns:** `List<Map<String, dynamic>>`
**Behavior:**
- Tries Kaggle API first
- Falls back to embedded if API fails
- Marks source as "Live" or "Embedded"

---

### 6. Check API Health
```dart
await KaggleDataService.getAPIStatus()
```
**Returns:** `Map<String, dynamic>` with status
**Use Case:** Quick health check without loading data
**Response:**
```json
{
  "connected": true,
  "authenticated": true,
  "status_code": 200
}
```

---

### 7. List All Kaggle Datasets
```dart
await KaggleDataService.listKaggleDatasets()
```
**Returns:** `List<Map<String, dynamic>>`
**Use Case:** Browse popular datasets on Kaggle
**Features:**
- Sorted by votes
- Up to 50 results
- Full metadata

---

### 8. Search Local Datasets
```dart
await KaggleDataService.searchDatasets('pcos')
```
**Returns:** `List<Map<String, dynamic>>`
**Use Case:** Filter loaded datasets locally
**Searches:** Name & description fields

---

### 9. Get Specific Dataset
```dart
await KaggleDataService.getDatasetByName('PCOS Symptoms Dataset')
```
**Returns:** `Map<String, dynamic>?`
**Use Case:** Find specific dataset by name

---

### 10. Export as JSON
```dart
await KaggleDataService.exportDatasetAsJson('PCOS Symptoms Dataset')
```
**Returns:** `String` (JSON)
**Use Case:** Export dataset data

---

## 📊 Data Structure Reference

### Dataset Object
```dart
{
  'id': 'dataset-id',                    // Kaggle dataset ID
  'ref': 'owner/dataset-name',           // Kaggle reference
  'title': 'Dataset Title',              // Display name
  'description': 'Full description...',  // Details
  'source': 'Kaggle API (Live)',         // Data source
  'downloads': 1250,                     // Download count
  'usability': 4.8,                      // Rating 1-5
  'owner': 'username',                   // Dataset creator
  'owner_url': 'https://...',           // Creator profile
  'url': 'https://kaggle.com/...',      // Kaggle URL
  'size_bytes': 2584512,                // File size
  'last_updated': '2026-01-15',         // Last modified
  'creation_date': '2025-06-10',        // Created
  'is_featured': true,                  // Featured flag
  'columns': ['col1', 'col2', ...],     // Dataset fields
}
```

### API Status Object
```dart
{
  'initialized': true,              // API is ready
  'connected': true,                // Can reach API
  'authenticated': true,            // Credentials valid
  'message': 'Connected successfully',
  'datasets_loaded': 24,           // Number of datasets
  'source': 'kaggle_api',          // Data source
  'live_data_available': true,     // Has live data
  'timestamp': '2026-02-09T...',  // When checked
}
```

---

## 🔄 Typical Usage Flow

```
1. App Startup
   └─ initializeKaggleAPI()
      ├─ ✅ Success → Store status
      └─ ❌ Fail → Still works (uses embedded)

2. User Requests Datasets
   └─ getRecommendedPcosDatasets()
      ├─ ✅ Kaggle available → Return live data
      └─ ⚠️ API failed → Return embedded data

3. User Searches
   └─ searchKaggleDatasets('query')
      ├─ ✅ Results found → Display
      └─ ⚠️ No results → Show message

4. User Views Details
   └─ fetchKaggleDatasetDetails('ref')
      ├─ ✅ Got details → Show full info
      └─ ⚠️ API failed → Show basic info

5. Anytime Check Status
   └─ getAPIStatus()
      └─ Return current connection state
```

---

## ⚡ Common Patterns

### Pattern 1: Load Data with Loading State
```dart
bool isLoading = true;
List<Map<String, dynamic>> datasets = [];

Future<void> loadData() async {
  isLoading = true;
  datasets = await KaggleDataService.getRecommendedPcosDatasets();
  isLoading = false;
}
```

### Pattern 2: Handle Errors
```dart
try {
  final datasets = await KaggleDataService.getRecommendedPcosDatasets();
  // Always succeeds (live or embedded)
} catch (e) {
  print('Error: $e'); // Rarely happens
}
```

### Pattern 3: Check Data Source
```dart
final datasets = await KaggleDataService.getAvailableDatasets();

for (var ds in datasets) {
  if (ds['source'].contains('Live')) {
    print('🔴 Live data: ${ds['title']}');
  } else {
    print('📦 Embedded data: ${ds['title']}');
  }
}
```

### Pattern 4: Display in List
```dart
FutureBuilder<List<Map<String, dynamic>>>(
  future: KaggleDataService.getRecommendedPcosDatasets(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    final datasets = snapshot.data ?? [];
    return ListView.builder(
      itemCount: datasets.length,
      itemBuilder: (ctx, i) => ListTile(
        title: Text(datasets[i]['title']),
        subtitle: Text('By: ${datasets[i]['owner']}'),
      ),
    );
  },
)
```

---

## 🎯 When to Use Each Method

| Need | Method | Time |
|------|--------|------|
| Check API on startup | `initializeKaggleAPI()` | 2-5s |
| Load PCOS datasets | `getRecommendedPcosDatasets()` | 3-5s |
| Search for dataset | `searchKaggleDatasets()` | 1-3s |
| Get dataset details | `fetchKaggleDatasetDetails()` | 1-2s |
| Quick health check | `getAPIStatus()` | 1-2s |
| Browse Kaggle | `listKaggleDatasets()` | 2-4s |
| Filter local | `searchDatasets()` | <100ms |
| Get by name | `getDatasetByName()` | <100ms |

---

## 📱 Display Examples

### Show Dataset Card
```dart
Card(
  child: ListTile(
    title: Text(dataset['title']),
    subtitle: Text(dataset['description']),
    trailing: Chip(
      label: Text('${dataset['downloads']} ⬇️'),
    ),
  ),
)
```

### Show with Rating
```dart
ListTile(
  title: Text(dataset['title']),
  subtitle: Row(
    children: [
      Text('⭐ ${dataset['usability'].toStringAsFixed(1)}'),
      SizedBox(width: 16),
      Text('📥 ${dataset['downloads']}'),
    ],
  ),
)
```

### Show Data Source Badge
```dart
Chip(
  label: dataset['source'].contains('Live') 
    ? Text('🔴 Live Data') 
    : Text('📦 Embedded'),
)
```

---

## 🔍 Debugging Tips

### Enable Verbose Logging
```dart
// All methods print detailed logs with emoji status
// Check console for:
// 🔍 Searches
// 📡 API responses
// ✅ Successes
// ⚠️ Warnings
// ❌ Errors
```

### Check What Data Source is Used
```dart
final status = await KaggleDataService.getAPIStatus();
print('Live API available: ${status['connected']}');

final datasets = await KaggleDataService.getAvailableDatasets();
print('Data from: ${datasets.first['source']}');
```

### Verify Data Integrity
```dart
final isValid = await KaggleDataService.verifyDataIntegrity();
print('Data is valid: $isValid');
```

---

## ✨ You're All Set!

Use these methods to integrate live Kaggle data into your app. All methods:
- ✅ Return properly typed data
- ✅ Handle errors gracefully
- ✅ Fall back automatically
- ✅ Include detailed logging
- ✅ Are production-ready

Happy coding! 🚀
