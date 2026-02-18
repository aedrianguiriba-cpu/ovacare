# Guest Mode Feature - Implementation Summary

## 🎯 Problem Solved

**Issue**: Users were seeing "Please sign in to save..." errors when trying to use the app after completing the screening quiz.

**Root Cause**: The app required authentication to save any health data (medications, symptoms, cycles), but users wanted to explore the app before committing to sign up.

**Solution**: Implemented **Guest Mode** that allows users to:
- Explore all app features immediately
- Track health data locally without sign-up 
- See a persistent banner prompting them to sign up for cloud sync
- Seamlessly convert to a full account later

---

## ✨ Features

### 1. Guest Mode Entry
- **Location**: Login Screen
- **Access**: "Continue as Guest" button below sign-in form
- **UX**: Clear info box explains data is stored locally only

### 2. Local Data Storage
When in guest mode, all health tracking works normally but data is stored only in app memory:
- ✅ Add medications
- ✅ Track symptoms
- ✅ Log menstrual cycles
- ✅ Toggle medication doses
- ✅ Complete risk assessments

**No "please sign in" errors** - everything just works!

### 3. Guest Mode Indicator
- **Location**: Top of Dashboard (banner)
- **Visual**: Amber/yellow color scheme with cloud-off icon
- **Message**: "Guest Mode: Data stored locally. Sign up to sync!"
- **Action**: "Sign Up" button for easy conversion

### 4. Sign Up Prompt
Users are gently encouraged to create an account:
- Non-intrusive banner (dismissible in future versions)
- Clear benefit messaging: "sync across devices"
- Easy access to signup from banner

---

## 🔧 Technical Implementation

### AuthProvider Changes

```dart
class AuthProvider extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isGuestMode = false;  // NEW: Track guest mode state
  // ... other properties

  void enterGuestMode() {
    isGuestMode = true;
    userName = 'Guest';
    notifyListeners();
  }

  void _syncFromSession(Session? session) {
    isLoggedIn = session != null;
    if (isLoggedIn) {
      isGuestMode = false; // Exit guest mode when logged in
    }
    // ... sync user data
  }
}
```

### Route Changes

```dart
'/': (context) {
  return Consumer<AuthProvider>(
    builder: (context, auth, _) {
      // Now accepts EITHER logged in OR guest mode
      if (auth.isLoggedIn || auth.isGuestMode) {
        return const DashboardScreen();
      }
      return const LoginScreen();
    },
  );
},
```

### Data Layer Changes

All CRUD operations now support guest mode:

**Before:**
```dart
Future<String?> addMedication(...) async {
  if (service == null || userId == null) {
    return 'Please sign in to save medications.'; // ❌ Error
  }
  // ... save to Supabase
}
```

**After:**
```dart
Future<String?> addMedication(...) async {
  if (service == null || userId == null) {
    // Guest mode: store locally only
    medications.insert(0, local);
    notifyListeners();
    return null; // ✅ Success (local only)
  }
  // ... save to Supabase
}
```

#### Updated Methods
- ✅ `addMedication()` - Stores locally if no auth
- ✅ `addSymptom()` - Stores locally if no auth
- ✅ `toggleMedication()` - Updates locally if no auth
- ✅ `addMenstrualEntry()` - Stores locally if no auth
- ✅ `togglePeriodDay()` - Updates locally if no auth
- ✅ `_syncCyclesToSupabase()` - Skips sync if no auth

---

## 🎨 UI Components

### Login Screen: Guest Mode Button

```dart
// Guest Mode Button
Center(
  child: TextButton.icon(
    icon: const Icon(Icons.person_outline, size: 18),
    label: const Text('Continue as Guest'),
    onPressed: () {
      context.read<AuthProvider>().enterGuestMode();
      Navigator.pushReplacementNamed(context, '/dashboard');
    },
  ),
),

// Info Box
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.blue[200]!),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Guest mode: Data stored locally only. Sign up to sync across devices.',
          style: TextStyle(fontSize: 11, color: Colors.blue[900]),
        ),
      ),
    ],
  ),
),
```

### Dashboard: Guest Mode Banner

```dart
if (auth.isGuestMode)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: Colors.amber[100],
    child: Row(
      children: [
        Icon(Icons.cloud_off, size: 20, color: Colors.amber[900]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Guest Mode: Data stored locally. Sign up to sync!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber[900],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignUpScreen()),
          ),
          child: Text('Sign Up', ...),
        ),
      ],
    ),
  ),
```

---

## 📊 Data Lifecycle

### Guest Mode Flow

1. **User completes screening quiz**
2. **LoginScreen shown**
3. **User taps "Continue as Guest"**
4. **AuthProvider.enterGuestMode()** called
   - Sets `isGuestMode = true`
   - Sets `userName = 'Guest'`
5. **Dashboard shown** with guest banner
6. **User tracks health data**
   - All data stored in app memory (HealthDataProvider)
   - No Supabase calls made
   - No error messages
7. **User decides to sign up**
   - Taps "Sign Up" from banner or settings
   - Creates account
   - **Data migration**: _(Not yet implemented - see Future Work)_

### Logged-In Flow

1. **User logs in or signs up**
2. **AuthProvider.\_syncFromSession()** called
   - Sets `isLoggedIn = true`
   - Sets `isGuestMode = false`
3. **HealthDataProvider loads data from Supabase**
4. **All subsequent saves sync to cloud**

---

## ⚠️ Limitations & Considerations

### Current Limitations

1. **No Data Persistence**: Guest data is lost when app closes
   - Data stored in app memory only
   - Not persisted to local storage or SharedPreferences
   - **Fix**: Add local persistence using Hive/SharedPreferences

2. **No Data Migration**: Guest data doesn't transfer when signing up
   - User must re-enter data after account creation
   - **Fix**: Implement migration function that syncs guest data to Supabase on signup

3. **Forum Access**: Guest users can view forum but not post
   - Forum posts require authenticated user ID
   - **Fix**: Allow guest posts with UUID, then link to account on signup

### Security Considerations

- ✅ Guest mode is read-only for Supabase (no DB access)
- ✅ Clear messaging about local-only storage
- ✅ No sensitive data exposure
- ✅ Easy path to full account

---

## 🚀 Future Enhancements

### Phase 1: Data Persistence (Priority: High)
```dart
// Add to HealthDataProvider
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _saveGuestData() async {
  if (!_isGuestMode) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('guest_meds', jsonEncode(medications));
  await prefs.setString('guest_cycles', jsonEncode(menstrualCycles));
  await prefs.setString('guest_symptoms', jsonEncode(symptoms));
}

Future<void> _loadGuestData() async {
  final prefs = await SharedPreferences.getInstance();
  final medsJson = prefs.getString('guest_meds');
  if (medsJson != null) {
    medications = jsonDecode(medsJson);
  }
  // ... load other data
}
```

### Phase 2: Data Migration (Priority: High)
```dart
// Add to AuthProvider
Future<void> migrateGuestDataToAccount(String userId) async {
  if (!isGuestMode) return;
  
  final healthProvider = context.read<HealthDataProvider>();
  
  // Upload all guest data to Supabase
  for (final med in healthProvider.medications) {
    await _supabaseHealthService.insertMedication(userId, med);
  }
  
  for (final symptom in healthProvider.symptoms) {
    await _supabaseHealthService.insertSymptom(userId, symptom);
  }
  
  await _supabaseHealthService.replaceMenstrualCycles(
    userId, 
    healthProvider.menstrualCycles,
  );
  
  // Clear guest flag
  isGuestMode = false;
  notifyListeners();
}
```

### Phase 3: Enhanced Guest UX
- Add dismissible banner option
- Show data sync progress during migration
- Add "Export Data" option for guests
- Periodic prompts to sign up (after adding X items)

---

## 📝 Testing Checklist

- [ ] Complete screening quiz and see LoginScreen
- [ ] Tap "Continue as Guest" and reach Dashboard
- [ ] See amber guest mode banner at top
- [ ] Add medication (should work, no errors)
- [ ] Track symptom (should work, no errors)
- [ ] Log menstrual cycle (should work, no errors)
- [ ] Toggle medication dose (should work, no errors)
- [ ] Tap "Sign Up" from banner → SignUpScreen shown
- [ ] Sign up → Guest banner disappears
- [ ] Log out → Return to LoginScreen
- [ ] Log back in → Data synced from Supabase

---

## 📚 Related Files

| File | Changes |
|------|---------|
| [main.dart](./lib/main.dart) | AuthProvider guest mode, route checks, data layer |
| [SUPABASE_INTEGRATION_COMPLETE.md](./SUPABASE_INTEGRATION_COMPLETE.md) | Overall integration status |
| [FORUM_SUPABASE_INTEGRATION.md](./FORUM_SUPABASE_INTEGRATION.md) | Forum-specific integration |

---

## 🎉 Result

**Before**: "Please sign in to save medications." ❌

**After**: Seamless guest experience with persistent upgrade prompts ✅

Users can now explore the full app immediately, track their health data locally, and choose to sign up when ready to sync across devices. No more blocking error messages!
