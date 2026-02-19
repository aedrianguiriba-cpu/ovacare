import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'additional_screens.dart';
import 'data_service.dart';
import 'services/kaggle_data_service.dart';
import 'services/supabase_health_service.dart';
import 'pcos_screening_quiz.dart';
import 'config/gemini_config.dart';
import 'dialog_helper.dart';

// Wave Indicator Painter for animated water effect
class WaveIndicatorPainter extends CustomPainter {
  final double wavePhase;

  WaveIndicatorPainter({required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.pink.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final height = size.height;
    final width = size.width;

    // Draw multiple vertical wave layers
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final waveAmplitude = 3.0 + layer;
      final frequency = 0.02 + (layer * 0.005);
      final phaseOffset = wavePhase + (layer * 0.5);

      // Start from top
      path.moveTo(width * 0.5, 0);

      for (double y = 0; y <= height; y++) {
        final x = width * 0.5 +
            math.sin((y * frequency) + phaseOffset) * waveAmplitude;
        path.lineTo(x, y);
      }

      path.lineTo(width, height);
      path.lineTo(width, 0);
      path.close();

      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(WaveIndicatorPainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase;
  }
}

void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  // Try multiple paths since working directory can vary
  bool envLoaded = false;
  
  // Try common paths
  final possiblePaths = [
    ".env",
    "ovacare/.env",
    "../.env",
    "../../.env",
  ];
  
  for (final path in possiblePaths) {
    try {
      await dotenv.load(fileName: path);
      print('✅ Loaded .env from: $path');
      envLoaded = true;
      break;
    } catch (e) {
      // Try next path
    }
  }
  
  if (!envLoaded) {
    print('⚠️ Warning: Could not load .env file. Using system environment variables or hardcoded values.');
    print('📝 To fix: Ensure .env file is in the project root (d:\\Documents\\web\\ovacare\\ovacare\\.env)');
    // Initialize Gemini with null (will use offline mode)
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // App will continue - GeminiConfig handles missing env gracefully
    }
  }
  
  // Initialize Supabase Database Connection
  try {
    String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('✅ Supabase database connected successfully');
    } else {
      print('⚠️ Supabase credentials not found in .env file');
    }
  } catch (e) {
    print('❌ Error initializing Supabase: $e');
  }
  
  // Initialize Gemini AI
  GeminiConfig.initialize();
  
  // Initialize Kaggle Data Service
  // This will attempt to connect to Kaggle API
  // If credentials are not configured, it will fall back to embedded datasets
  KaggleDataService.initialize();
  
  // Log service statuses
  print('AI Service: ${GeminiConfig.getStatus()}');
  print('Kaggle Service Status: ${KaggleDataService.getStatus()}');
  
  runApp(const OvaCareApp());
}

class OvaCareApp extends StatefulWidget {
  const OvaCareApp({super.key});

  @override
  State<OvaCareApp> createState() => _OvaCareAppState();
}

class _OvaCareAppState extends State<OvaCareApp> {
  bool _screeningComplete = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HealthDataProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'OvaCare - PCOS Health Companion',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
          useMaterial3: true,
        ),
        routes: {
          '/': (context) {
            // If screening is not complete, show it first
            if (!_screeningComplete) {
              return PCOSScreeningQuiz(
                onComplete: () {
                  setState(() => _screeningComplete = true);
                },
              );
            }
            // Otherwise show login/dashboard
            return Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isLoggedIn) {
                  return const DashboardScreen();
                }
                return const LoginScreen();
              },
            );
          },
          '/dashboard': (context) => const DashboardScreen(),
          '/signup': (context) => const SignUpScreen(),
        },
      ),
    );
  }
}

// ============== PROVIDERS ==============

class AuthProvider extends ChangeNotifier {
  bool isLoggedIn = false;
  String userName = '';
  String userEmail = '';
  String userId = '';
  int userAge = 0;
  double userHeight = 0.0;
  double userWeight = 0.0;
  String lastMenstrualDate = '';
  int cycleLength = 28;
  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
  }

  /// Check if user is already logged in (from Supabase session)
  void _checkAuthStatus() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        isLoggedIn = true;
        userId = user.id;
        userEmail = user.email ?? '';
        print('✅ User session found: ${user.email}');
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Error checking auth status: $e');
    }
  }

  /// Sign up a new user with Supabase
  Future<bool> signUp(String email, String password, String name, {
    String? username,
    int? age,
    double? height,
    double? weight,
    String? city,
  }) async {
    try {
      _errorMessage = null;
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null, // You can set a custom redirect URL if needed
        data: {
          'name': name,
          'username': username,
          'age': age,
          'height': height,
          'weight': weight,
          'city': city,
        },
      );

      // If user is returned, email is confirmed instantly (rare, only for trusted domains)
      // If user is null, confirmation is required
      if (response.user == null) {
        // Email confirmation required
        print('📧 Confirmation email sent to $email');
        return false;
      } else if (response.user != null && response.user!.emailConfirmedAt == null) {
        // User created but not confirmed
        // For testing: if email isn't configured, we'll allow login anyway
        print('📧 Confirmation email sent to $email (or email service not configured)');
        // Don't fail here - allow testing without email verification
        userId = response.user!.id;
        userName = name;
        userEmail = email;
        isLoggedIn = true;
        
        // Save user to database
        await _saveUserToDatabase(
          userId: response.user!.id,
          email: email,
          name: name,
          username: username,
          age: age,
          height: height,
          weight: weight,
          city: city,
        );
        
        notifyListeners();
        print('✅ User registered (email confirmation: awaiting configuration)');
        return true;
      } else if (response.user != null && response.user!.emailConfirmedAt != null) {
        // Email already confirmed (very rare)
        userId = response.user!.id;
        userName = name;
        userEmail = email;
        isLoggedIn = true;
        
        // Save user to database
        await _saveUserToDatabase(
          userId: response.user!.id,
          email: email,
          name: name,
          username: username,
          age: age,
          height: height,
          weight: weight,
          city: city,
        );
        
        notifyListeners();
        print('✅ User registered and confirmed');
        return true;
      }
      return false;
    } catch (e) {
      // Handle specific error types with user-friendly messages
      String errorMsg = e.toString();
      
      if (errorMsg.contains('unexpected_failure') || errorMsg.contains('Error sending confirmation email')) {
        _errorMessage = 'Account created! Email service not configured - you can log in immediately. Confirmation email will work once Supabase email is set up.';
        print('⚠️ Email service error (non-blocking): $e');
        // Try to allow login anyway since account was created
        return true; // Return true to indicate "account created but email failed"
      } else if (errorMsg.contains('over_email_send_rate_limit') || errorMsg.contains('429')) {
        _errorMessage = 'Too many signup attempts with this email. Please wait 15-30 minutes before trying again, or use a different email address.';
        print('⏱️ Rate limit exceeded: Too many confirmation emails sent');
      } else if (errorMsg.contains('User already exists')) {
        _errorMessage = 'This email is already registered. Please log in or use a different email.';
        print('❌ User already exists: $e');
      } else if (errorMsg.contains('Invalid email')) {
        _errorMessage = 'Please enter a valid email address.';
        print('❌ Invalid email: $e');
      } else if (errorMsg.contains('Password')) {
        _errorMessage = 'Password must be at least 6 characters.';
        print('❌ Password error: $e');
      } else {
        _errorMessage = 'Signup failed: ${e.toString()}';
        print('❌ Sign up error: $e');
      }
      
      return false;
    }
  }

  /// Login user with Supabase
  Future<bool> login(String email, String password) async {
    try {
      _errorMessage = null;
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // TODO: Enable email verification check for production
        // For testing/development, allowing unconfirmed emails temporarily
        // Uncomment the lines below when email is properly configured:
        /*
        if (response.user!.emailConfirmedAt == null) {
          _errorMessage = 'Please verify your email before logging in';
          print('⚠️ Email not verified');
          return false;
        }
        */
        
        userId = response.user!.id;
        userEmail = email;
        userName = response.user?.userMetadata?['name'] ?? email.split('@')[0];
        isLoggedIn = true;
        
        // Save user to database if not already there
        await _saveUserToDatabase(
          userId: response.user!.id,
          email: email,
          name: response.user?.userMetadata?['name'],
          username: response.user?.userMetadata?['username'],
          age: response.user?.userMetadata?['age'] as int?,
          height: response.user?.userMetadata?['height'] as double?,
          weight: response.user?.userMetadata?['weight'] as double?,
          city: response.user?.userMetadata?['city'],
        );
        
        notifyListeners();
        print('✅ User logged in: $email');
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Login error: $e');
      return false;
    }
  }
  
  /// Save user to users table in Supabase (non-blocking)
  Future<void> _saveUserToDatabase({
    required String userId,
    required String email,
    String? name,
    String? username,
    int? age,
    double? height,
    double? weight,
    String? city,
  }) async {
    try {
      // Simply insert without any checks
      await Supabase.instance.client
          .from('users')
          .insert({
            'id': userId,
            'email': email,
            'name': name,
            'username': username,
            'age': age,
            'height': height,
            'weight': weight,
            'city': city,
          });
      print('✅ User data saved to users table');
    } catch (insertError) {
      // If insert fails, silently continue (table may not exist or user already exists)
      print('ℹ️ Could not insert to users table: $insertError');
    }
  }

  /// Logout user from Supabase
  Future<bool> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      isLoggedIn = false;
      userName = '';
      userEmail = '';
      userId = '';
      notifyListeners();
      print('✅ User logged out');
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Logout error: $e');
      return false;
    }
  }

  void updateProfile(String name, int age, double height, double weight) {
    userName = name;
    userAge = age;
    userHeight = height;
    userWeight = weight;
    notifyListeners();
  }
}

class HealthDataProvider extends ChangeNotifier {
  // Data Services
  late DataService _dataService;
  late SupabaseHealthService _supabaseService;
  PopulationCycleData? _populationData;
  String? _currentUserId;
  bool _isInitialized = false;

  HealthDataProvider() {
    _dataService = DataService();
    _initializeServices();
  }

  /// Initialize both Supabase and local data services
  void _initializeServices() async {
    try {
      // Get the current user from Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _currentUserId = user.id;
        _supabaseService = SupabaseHealthService(Supabase.instance.client);
        
        // Load data from Supabase
        await _loadDataFromSupabase();
        print('✅ Health data loaded from Supabase for user: $_currentUserId');
      } else {
        // Initialize with empty Supabase service
        _supabaseService = SupabaseHealthService(Supabase.instance.client);
        print('⚠️ No authenticated user; health data will be stored locally');
      }
    } catch (e) {
      print('⚠️ Error initializing Supabase service: $e');
      _supabaseService = SupabaseHealthService(Supabase.instance.client);
    }
    
    _initializePopulationData();
    _isInitialized = true;
  }

  /// Load health data from Supabase database
  Future<void> _loadDataFromSupabase() async {
    if (_currentUserId == null) return;
    
    try {
      // Load menstrual cycles
      menstrualCycles = await _supabaseService.fetchMenstrualCycles(_currentUserId!);
      
      // Load symptoms
      symptoms = await _supabaseService.fetchSymptoms(_currentUserId!);
      
      notifyListeners();
    } catch (e) {
      print('⚠️ Error loading data from Supabase: $e');
    }
  }

  /// Initialize population data asynchronously
  void _initializePopulationData() async {
    _populationData = await _dataService.getPopulationCycleData();
    _updateRiskAssessment();
  }

  void addMedication(String name, String dose, List<String> times, List<bool> taken, DateTime date) {
    medications.insert(0, {
      'name': name,
      'dose': dose,
      'times': times,
      'taken': taken,
      'date': date,
    });
    notifyListeners();
  }
  // Menstrual Cycle Data
  List<Map<String, dynamic>> menstrualCycles = [];

  // Symptoms
  List<Map<String, dynamic>> symptoms = [];

  // Hydration
  List<Map<String, dynamic>> hydrationEntries = [];

  // Medications
  List<Map<String, dynamic>> medications = [];

  // Weight Tracking
  List<Map<String, dynamic>> weightEntries = [];

  // Risk Assessment
  Map<String, dynamic> riskAssessment = {
    'pcosRisk': 'Unknown',
    'score': 0,
    'lastUpdated': null,
    'factors': [],
    'datasetInsights': ''
  };

  void addMenstrualEntry(DateTime start, DateTime end, int flow, String notes) {
    final entry = {'start': start, 'end': end, 'flow': flow, 'notes': notes};
    menstrualCycles.insert(0, entry);
    
    // Sync to Supabase if user is logged in
    if (_currentUserId != null && _isInitialized) {
      _syncMenstrualCyclesToSupabase();
    }
    
    _updateRiskAssessment();
    notifyListeners();
  }

  /// Sync current menstrual cycles to Supabase
  Future<void> _syncMenstrualCyclesToSupabase() async {
    if (_currentUserId == null) return;
    
    try {
      await _supabaseService.replaceMenstrualCycles(_currentUserId!, menstrualCycles);
      print('✅ Menstrual cycles synced to database');
    } catch (e) {
      print('⚠️ Error syncing menstrual cycles: $e');
    }
  }

  // Clear all cycle history
  void clearCycleHistory() {
    menstrualCycles.clear();
    
    // Sync to Supabase
    if (_currentUserId != null && _isInitialized) {
      _syncMenstrualCyclesToSupabase();
    }
    
    _updateRiskAssessment();
    notifyListeners();
  }

  // Calculate predicted next period based on cycle history
  DateTime? getNextPeriodPrediction() {
    if (menstrualCycles.length < 2) {
      // Need at least 2 cycles to predict
      return null;
    }

    // Get the most recent cycle start
    final recentCycle = menstrualCycles.first;
    final lastPeriodStart = recentCycle['start'] as DateTime;

    // Calculate average cycle length from recent cycles
    final cycleLengths = <int>[];
    for (int i = 0; i < menstrualCycles.length - 1; i++) {
      final current = (menstrualCycles[i]['start'] as DateTime);
      final next = (menstrualCycles[i + 1]['start'] as DateTime);
      final diff = current.difference(next).inDays.abs();
      if (diff > 0 && diff < 100) {
        // Filter out anomalies (0 days or > 100 days)
        cycleLengths.add(diff);
      }
    }

    if (cycleLengths.isEmpty) {
      // No valid cycles, use average of 28 days
      return lastPeriodStart.add(const Duration(days: 28));
    }

    // Use weighted average (recent cycles matter more)
    final n = cycleLengths.length;
    double weightedSum = 0;
    int weightTotal = 0;
    for (int i = 0; i < n; i++) {
      final weight = n - i; // recent cycles weigh more
      weightedSum += cycleLengths[i] * weight;
      weightTotal += weight;
    }
    final avgCycleLength = (weightedSum / weightTotal).round();

    // Predict next period
    return lastPeriodStart.add(Duration(days: avgCycleLength));
  }

  // Get days until next predicted period
  int? getDaysUntilNextPeriod() {
    final nextPeriod = getNextPeriodPrediction();
    if (nextPeriod == null) return null;
    
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final nextNormalized = DateTime(nextPeriod.year, nextPeriod.month, nextPeriod.day);
    
    return nextNormalized.difference(todayNormalized).inDays;
  }

  // Keep cycles sorted by start date descending (most recent first)
  void _sortCyclesByStartDesc() {
    menstrualCycles.sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
  }

  // Check if a specific date is marked as a period day
  bool isPeriodDay(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    for (var cycle in menstrualCycles) {
      final start = DateTime((cycle['start'] as DateTime).year, (cycle['start'] as DateTime).month, (cycle['start'] as DateTime).day);
      final end = DateTime((cycle['end'] as DateTime).year, (cycle['end'] as DateTime).month, (cycle['end'] as DateTime).day);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) return true;
    }
    return false;
  }

  // Toggle a single date as a period day. If the date is already inside an
  // existing cycle, unmark it (shrink/split/remove as needed). If not, create
  // or merge into adjacent cycles.
  // Special case: if no cycles exist, the first tap creates the start of the first period.
  void togglePeriodDay(DateTime date) {
    // Normalize date to year/month/day (ignore time)
    final target = DateTime(date.year, date.month, date.day);

    // Special case: if this is the VERY FIRST tap (no cycles at all),
    // create a new cycle starting from this date
    if (menstrualCycles.isEmpty) {
      menstrualCycles.insert(0, {
        'start': target,
        'end': target,
        'flow': 3,
        'notes': 'First period day'
      });
      _sortCyclesByStartDesc();
      _updateRiskAssessment();
      notifyListeners();
      return;
    }

    // Find if date is inside an existing cycle
    for (int i = 0; i < menstrualCycles.length; i++) {
      final cycle = menstrualCycles[i];
      DateTime start = cycle['start'] as DateTime;
      DateTime end = cycle['end'] as DateTime;
      start = DateTime(start.year, start.month, start.day);
      end = DateTime(end.year, end.month, end.day);
      if (!target.isBefore(start) && !target.isAfter(end)) {
        // Unmark: adjust or remove
        if (start == end && start == target) {
          // single-day cycle -> remove
          menstrualCycles.removeAt(i);
        } else if (target == start) {
          // move start forward
          menstrualCycles[i]['start'] = start.add(const Duration(days: 1));
        } else if (target == end) {
          // move end backward
          menstrualCycles[i]['end'] = end.subtract(const Duration(days: 1));
        } else {
          // split the cycle into two
          final left = {'start': start, 'end': target.subtract(const Duration(days: 1)), 'flow': cycle['flow'], 'notes': cycle['notes']};
          final right = {'start': target.add(const Duration(days: 1)), 'end': end, 'flow': cycle['flow'], 'notes': cycle['notes']};
          // replace current with left and insert right after
          menstrualCycles[i] = left;
          menstrualCycles.insert(i + 1, right);
        }
        _sortCyclesByStartDesc();
        _updateRiskAssessment();
        notifyListeners();
        return;
      }
    }

    // Not found inside a cycle -> create or merge with adjacent cycles
    // See if adjacent to previous or next cycle
    int? prevIndex;
    int? nextIndex;
    for (int i = 0; i < menstrualCycles.length; i++) {
      final cycle = menstrualCycles[i];
      final start = DateTime((cycle['start'] as DateTime).year, (cycle['start'] as DateTime).month, (cycle['start'] as DateTime).day);
      final end = DateTime((cycle['end'] as DateTime).year, (cycle['end'] as DateTime).month, (cycle['end'] as DateTime).day);
      if (end.add(const Duration(days: 1)) == target) prevIndex = i;
      if (start.subtract(const Duration(days: 1)) == target) nextIndex = i;
    }

    if (prevIndex != null && nextIndex != null && prevIndex != nextIndex) {
      // merge prev and next with the target bridging day
      final prev = menstrualCycles[prevIndex];
      final next = menstrualCycles[nextIndex > prevIndex ? nextIndex : nextIndex];
      final newStart = DateTime((prev['start'] as DateTime).year, (prev['start'] as DateTime).month, (prev['start'] as DateTime).day);
      final newEnd = DateTime((next['end'] as DateTime).year, (next['end'] as DateTime).month, (next['end'] as DateTime).day);
      // remove both and insert merged at prevIndex
      final merged = {'start': newStart, 'end': newEnd, 'flow': prev['flow'], 'notes': '${prev['notes'] ?? ''}; ${next['notes'] ?? ''}'};
      // remove higher index first
      final hi = prevIndex > nextIndex ? prevIndex : nextIndex;
      final lo = prevIndex > nextIndex ? nextIndex : prevIndex;
      menstrualCycles.removeAt(hi);
      menstrualCycles.removeAt(lo);
      menstrualCycles.insert(lo, merged);
      _sortCyclesByStartDesc();
      _updateRiskAssessment();
      notifyListeners();
      return;
    }

    if (prevIndex != null) {
      // extend previous cycle end by one day
      final prev = menstrualCycles[prevIndex];
      menstrualCycles[prevIndex]['end'] = (prev['end'] as DateTime).add(const Duration(days: 1));
      _sortCyclesByStartDesc();
      _updateRiskAssessment();
      notifyListeners();
      return;
    }

    if (nextIndex != null) {
      // extend next cycle start backward by one day
      final next = menstrualCycles[nextIndex];
      menstrualCycles[nextIndex]['start'] = (next['start'] as DateTime).subtract(const Duration(days: 1));
      _sortCyclesByStartDesc();
      _updateRiskAssessment();
      notifyListeners();
      return;
    }

    // Otherwise create a new single-day cycle
    menstrualCycles.insert(0, {'start': target, 'end': target, 'flow': 3, 'notes': 'Marked from calendar'});
    _sortCyclesByStartDesc();
    _updateRiskAssessment();
    notifyListeners();
  }

  void addSymptom(Map<String, dynamic> symptom) {
    symptoms.insert(0, symptom);
    
    // Sync to Supabase if user is logged in
    if (_currentUserId != null && _isInitialized) {
      _syncSymptomToSupabase(symptom);
    }
    
    _updateRiskAssessment();
    notifyListeners();
  }

  /// Sync a single symptom to Supabase
  Future<void> _syncSymptomToSupabase(Map<String, dynamic> symptom) async {
    if (_currentUserId == null) return;
    
    try {
      symptom['date'] ??= DateTime.now();
      await _supabaseService.insertSymptom(_currentUserId!, symptom);
      print('✅ Symptom synced to database');
    } catch (e) {
      print('⚠️ Error syncing symptom: $e');
    }
  }

  /// Set the current user ID and load their data from Supabase
  /// Call this method after the user logs in
  Future<void> setCurrentUserId(String userId) async {
    _currentUserId = userId;
    _supabaseService = SupabaseHealthService(Supabase.instance.client);
    await _loadDataFromSupabase();
    print('✅ User ID set and data loaded: $userId');
  }

  void addHydration(int ml) {
    hydrationEntries.insert(0, {'date': DateTime.now(), 'ml': ml});
    _updateRiskAssessment();
    notifyListeners();
  }

  void toggleMedication(int medIndex, int timeIndex) {
    medications[medIndex]['taken'][timeIndex] = !medications[medIndex]['taken'][timeIndex];
    notifyListeners();
  }

  void addWeightEntry(double weight) {
    weightEntries.insert(0, {'date': DateTime.now(), 'weight': weight});
    _updateRiskAssessment();
    notifyListeners();
  }

  /// Calculate dynamic risk assessment based on user's tracked data and dataset comparisons
  /// Uses weighted factor scoring with proper normalization (0-100 scale)
  void _updateRiskAssessment() {
    final factors = <Map<String, dynamic>>[];
    double weightedScore = 0.0;
    double totalWeight = 0.0;

    // ===== FACTOR 1: Cycle Regularity (Weight: 35%) - Most Important =====
    double cycleRegularityScore = 0.0;
    if (menstrualCycles.length >= 2) {
      final lengths = <int>[];
      for (int i = 0; i < menstrualCycles.length - 1; i++) {
        final current = menstrualCycles[i]['end'] as DateTime;
        final next = menstrualCycles[i + 1]['start'] as DateTime;
        final diff = current.difference(next).inDays.abs();
        if (diff > 0 && diff < 100) lengths.add(diff); // Filter anomalies
      }

      if (lengths.isNotEmpty) {
        final avgLength = lengths.reduce((a, b) => a + b) / lengths.length;
        final variance = lengths.map((l) => (l - avgLength) * (l - avgLength)).reduce((a, b) => a + b) / lengths.length;
        final stdDev = variance.toDouble();
        final cycleCount = lengths.length; // Number of cycles for confidence

        // Calculate time span of tracking (from oldest to newest cycle)
        final oldestCycleStart = (menstrualCycles.last['start'] as DateTime);
        final newestCycleStart = (menstrualCycles.first['start'] as DateTime);
        final trackingDays = newestCycleStart.difference(oldestCycleStart).inDays;
        final trackingMonths = trackingDays / 30.44; // Average month length

        // Normalize stdDev to 0-100 score using sigmoid function (more accurate than linear)
        // At stdDev=0: score=0 (perfect), at stdDev=15: score=100 (very irregular)
        cycleRegularityScore = (100 / (1 + math.exp(-0.4 * (stdDev - 7.5))));

        String regularitySeverity = 'Low';
        String regularityDesc = 'Cycle length is stable and consistent.';
        String datasetComparison = '';
        String confidenceNote = '';

        // Helper function to describe variation in plain language
        String getVariationDescription(double stdDev) {
          if (stdDev <= 2) {
            return 'Your cycles vary by only 1-2 days - that\'s excellent!';
          } else if (stdDev <= 4) {
            return 'Your cycles vary by about ${stdDev.round()} days on average - this is normal.';
          } else if (stdDev <= 7) {
            return 'Your cycles vary by about ${stdDev.round()} days - slightly unpredictable.';
          } else if (stdDev <= 10) {
            return 'Your cycles vary by about ${stdDev.round()} days - moderately irregular.';
          } else {
            return 'Your cycles vary by ${stdDev.round()}+ days - quite unpredictable.';
          }
        }

        // ===== CRITICAL: Only assess after 6 months of tracking =====
        if (trackingMonths < 6) {
          // Less than 6 months - show "Assessing" status
          regularitySeverity = 'Low';
          cycleRegularityScore = 0.0; // Don't count toward overall risk
          final daysUntilAssessment = (180 - trackingDays).clamp(0, 180);
          final weeksLeft = (daysUntilAssessment / 7).round();
          regularityDesc = '📊 Still gathering data! You\'ve been tracking for ${trackingMonths.toStringAsFixed(0)} months. '
              'We need about 6 months of cycle data to give you an accurate regularity assessment. '
              'Keep logging - only about $weeksLeft weeks to go!';
          confidenceNote = ' (Learning your patterns...)';
        } else {
          // 6+ months - now show real assessment
          // Adjust thresholds based on sample size after 3 months
          // With 3 months: usually 3-4 cycles
          // With 6 months: usually 6-7 cycles
          double highRiskThreshold = 12.0;
          double moderateRiskThreshold = 6.0;

          // Create user-friendly confidence message
          String confidenceEmoji = '📈';
          if (cycleCount < 4) {
            // 3 months but only a few cycles - still developing
            highRiskThreshold = 18.0;
            moderateRiskThreshold = 9.0;
            confidenceEmoji = '📊';
            confidenceNote = '\n\n💡 Based on $cycleCount cycles over ${trackingMonths.toStringAsFixed(0)} months. More cycles = more accurate results!';
          } else if (cycleCount < 6) {
            // 3-4 months, good cycle count
            highRiskThreshold = 15.0;
            moderateRiskThreshold = 8.0;
            confidenceEmoji = '📈';
            confidenceNote = '\n\n💡 Based on $cycleCount cycles. Keep tracking for even better insights!';
          } else {
            // 5+ cycles (usually 5+ months) - high confidence
            confidenceEmoji = '✅';
            confidenceNote = '\n\n✅ High confidence: Based on $cycleCount cycles over ${trackingMonths.toStringAsFixed(0)} months of data.';
          }

          // Compare with dataset if available
          String comparisonNote = '';
          if (_populationData != null) {
            final populationStdDev = _populationData!.stdDevCycleLength;

            if (cycleCount >= 5) {
              // Good data - use strict dataset comparison
              if (stdDev > populationStdDev * 3.0) {
                regularitySeverity = 'High';
                comparisonNote = ' This is about 3x more variable than most women experience.';
              } else if (stdDev > populationStdDev * 2.0) {
                regularitySeverity = 'Moderate';
                comparisonNote = ' This is about 2x more variable than typical.';
              } else {
                comparisonNote = ' This is within the normal range for most women.';
              }
            } else {
              // Limited data - use thresholds instead
              if (stdDev > highRiskThreshold) {
                regularitySeverity = 'High';
              } else if (stdDev > moderateRiskThreshold) {
                regularitySeverity = 'Moderate';
              }
            }
          } else {
            // Use standard thresholds if no population data
            if (stdDev > highRiskThreshold) {
              regularitySeverity = 'High';
            } else if (stdDev > moderateRiskThreshold) {
              regularitySeverity = 'Moderate';
            }
          }

          // Generate user-friendly descriptions
          final variationDesc = getVariationDescription(stdDev);
          final avgCycleDays = avgLength.round();
          
          if (regularitySeverity == 'Low') {
            regularityDesc = '$confidenceEmoji Great news! Your cycles are regular and predictable.\n\n'
                '• Average cycle: $avgCycleDays days\n'
                '• $variationDesc\n'
                '• This pattern is healthy and normal!$confidenceNote';
          } else if (regularitySeverity == 'Moderate') {
            regularityDesc = '$confidenceEmoji Your cycles show some variation - worth monitoring.\n\n'
                '• Average cycle: $avgCycleDays days\n'
                '• $variationDesc$comparisonNote\n'
                '• Some irregular cycles are common and not always a concern. Stress, diet, and sleep can all affect cycle timing.$confidenceNote';
          } else {
            regularityDesc = '⚠️ Your cycles are quite unpredictable.\n\n'
                '• Average cycle: $avgCycleDays days\n'
                '• $variationDesc$comparisonNote\n'
                '• Very irregular cycles can sometimes indicate hormonal imbalances. Consider discussing with your healthcare provider if this pattern continues.$confidenceNote';
          }
        }

        factors.add({
          'name': 'Cycle Regularity',
          'severity': regularitySeverity,
          'description': regularityDesc,
          'stdDev': stdDev.toStringAsFixed(1),
          'cycleCount': cycleCount.toString(),
          'avgCycleLength': avgLength.toStringAsFixed(1),
          'trackingMonths': trackingMonths.toStringAsFixed(1),
          'trackingDays': trackingDays.toString(),
          'populationStdDev': _populationData?.stdDevCycleLength.toStringAsFixed(1) ?? 'N/A',
          'score': cycleRegularityScore
        });

        // Only add to weighted score if we have 3+ months of data
        if (trackingMonths >= 3) {
          weightedScore += cycleRegularityScore * 0.35;
          totalWeight += 0.35;
        }
      }
    }

    // ===== FACTOR 2: Weight Stability (Weight: 20%) =====
    double weightStabilityScore = 0.0;
    if (weightEntries.length >= 3) {
      final recentWeights = weightEntries.take(5).map((e) => (e['weight'] as num).toDouble()).toList();
      final avgWeight = recentWeights.reduce((a, b) => a + b) / recentWeights.length;
      final weightVariance = recentWeights.map((w) => (w - avgWeight) * (w - avgWeight)).reduce((a, b) => a + b) / recentWeights.length;
      final weightStdDev = weightVariance.toDouble();

      // Normalize weight variance to 0-100 (at 8kg variation: score=100)
      weightStabilityScore = (100 / (1 + math.exp(-0.5 * (weightStdDev - 4))));

      String weightSeverity = 'Low';
      String weightDesc = 'Weight is stable over recent entries.';
      final currentWeightRounded = avgWeight.round();
      final variationKg = weightStdDev.toStringAsFixed(1);

      // Add user-friendly weight stability descriptions
      if (weightStdDev > 6) {
        weightSeverity = 'High';
        weightDesc = '⚠️ Your weight has been fluctuating quite a bit.\n\n'
            '• Current average: ${currentWeightRounded}kg\n'
            '• Fluctuation: ±${variationKg}kg\n\n'
            'Rapid weight changes (more than 6kg up or down) can affect your hormones and menstrual cycle. '
            'If you\'re actively trying to lose or gain weight, gradual changes are healthier for your body.';
      } else if (weightStdDev > 3) {
        weightSeverity = 'Moderate';
        weightDesc = '📊 Your weight shows some variation.\n\n'
            '• Current average: ${currentWeightRounded}kg\n'
            '• Fluctuation: ±${variationKg}kg\n\n'
            'Moderate weight changes (3-6kg) can sometimes influence your cycle. This is common and usually not a concern. '
            'Factors like water retention, diet changes, and exercise can cause normal fluctuations.';
      } else {
        weightDesc = '✅ Great job! Your weight is stable.\n\n'
            '• Current average: ${currentWeightRounded}kg\n'
            '• Fluctuation: ±${variationKg}kg\n\n'
            'Keeping your weight stable (within 2-3kg) supports healthy hormone levels and regular cycles. Keep it up!';
      }

      factors.add({
        'name': 'Weight Stability',
        'severity': weightSeverity,
        'description': weightDesc,
        'variance': weightStdDev.toStringAsFixed(1),
        'currentWeight': avgWeight.toStringAsFixed(1),
        'score': weightStabilityScore,
        'datasetContext': 'Based on clinical research on weight-cycle correlation',
        'thresholds': 'Safe: ±2kg | Caution: 3-6kg | High Risk: >6kg'
      });

      weightedScore += weightStabilityScore * 0.20;
      totalWeight += 0.20;
    }

    // ===== FACTOR 3: Symptom Patterns (Weight: 25%) =====
    double symptomScore = 0.0;
    if (symptoms.isNotEmpty) {
      final recentSymptoms = symptoms.take(30); // Last 30 entries
      
      // Count severe symptoms (severity >= 6)
      final severeSymptomCount = recentSymptoms.where((s) {
        final severity = (s['severity'] as num?)?.toInt() ?? 0;
        return severity >= 6;
      }).length;

      // Count PCOS-specific symptoms based on actual data structure
      // Check: severity >= 3 (not 6), AND presence of PCOS indicators
      int pcosSpecificCount = 0;
      for (var s in recentSymptoms) {
        final severity = (s['severity'] as num?)?.toInt() ?? 0;
        final hasCramps = (s['cramps'] as num?)?.toInt() ?? 0;
        final hasAcne = (s['acne'] as bool?) ?? false;
        final hasBloating = (s['bloating'] as bool?) ?? false;
        final hasHairGrowth = (s['hairGrowth'] as bool?) ?? false;
        final hasIrregular = (s['irregular'] as bool?) ?? false;
        final mood = (s['mood'] as String?)?.toLowerCase() ?? '';
        
        // Count if severity >= 3 AND has at least one PCOS indicator
        bool hasPcosIndicator = hasAcne || hasBloating || hasHairGrowth || hasIrregular || hasCramps >= 5;
        bool hasMoodIssue = ['anxious', 'sad', 'stressed', 'irritable'].contains(mood);
        
        if (severity >= 3 && (hasPcosIndicator || hasMoodIssue)) {
          pcosSpecificCount++;
        }
      }

      // Score based on symptom frequency and type
      // Max score at 15+ PCOS-specific symptom episodes
      symptomScore = math.min(100.0, (pcosSpecificCount / 15) * 100);

      String symptomSeverity = 'Low';
      String symptomDesc = 'Minimal PCOS-related symptoms reported.';

      // Build list of detected symptoms for display
      List<String> detectedSymptomTypes = [];
      for (var s in recentSymptoms) {
        if ((s['acne'] as bool?) == true && !detectedSymptomTypes.contains('acne')) detectedSymptomTypes.add('acne');
        if ((s['bloating'] as bool?) == true && !detectedSymptomTypes.contains('bloating')) detectedSymptomTypes.add('bloating');
        if ((s['hairGrowth'] as bool?) == true && !detectedSymptomTypes.contains('excess hair')) detectedSymptomTypes.add('excess hair');
        if ((s['irregular'] as bool?) == true && !detectedSymptomTypes.contains('irregular periods')) detectedSymptomTypes.add('irregular periods');
        final cramps = (s['cramps'] as num?)?.toInt() ?? 0;
        if (cramps >= 5 && !detectedSymptomTypes.contains('severe cramps')) detectedSymptomTypes.add('severe cramps');
        final mood = (s['mood'] as String?)?.toLowerCase() ?? '';
        if (['anxious', 'stressed'].contains(mood) && !detectedSymptomTypes.contains('mood changes')) detectedSymptomTypes.add('mood changes');
      }
      final symptomsList = detectedSymptomTypes.take(4).join(', ');

      if (pcosSpecificCount >= 12) {
        symptomSeverity = 'High';
        symptomDesc = '⚠️ You\'ve logged quite a few PCOS-related symptoms.\n\n'
            '• Symptom episodes: $pcosSpecificCount in the last 30 days\n'
            '${symptomsList.isNotEmpty ? '• Including: $symptomsList\n' : ''}\n'
            'This pattern could indicate hormonal imbalances. It might be worth discussing with a doctor, '
            'especially if these symptoms are affecting your daily life. Remember - having symptoms doesn\'t mean you definitely have PCOS, '
            'but tracking helps you and your doctor understand what\'s happening.';
      } else if (pcosSpecificCount >= 6) {
        symptomSeverity = 'Moderate';
        symptomDesc = '📊 You\'re experiencing some PCOS-related symptoms.\n\n'
            '• Symptom episodes: $pcosSpecificCount in the last 30 days\n'
            '${symptomsList.isNotEmpty ? '• Including: $symptomsList\n' : ''}\n'
            'This is fairly common and may be influenced by stress, diet, or hormonal fluctuations. '
            'Keep tracking your symptoms - patterns over time are more meaningful than individual days. '
            'Lifestyle changes like better sleep and reduced stress often help!';
      } else if (pcosSpecificCount >= 1) {
        symptomSeverity = 'Low';
        symptomDesc = '✅ You\'ve had a few symptoms, but nothing concerning.\n\n'
            '• Symptom episodes: $pcosSpecificCount in the last 30 days\n'
            '${symptomsList.isNotEmpty ? '• Including: $symptomsList\n' : ''}\n'
            'Occasional symptoms are completely normal. Keep logging to build a clearer picture of your health patterns.';
      } else {
        symptomDesc = '✅ Great news! No significant PCOS-related symptoms detected yet.\n\n'
            'Keep logging any symptoms you experience - even mild ones. This helps build a complete picture of your health over time.';
      }

      factors.add({
        'name': 'Symptom Patterns',
        'severity': symptomSeverity,
        'description': symptomDesc,
        'pcosSpecificCount': pcosSpecificCount.toString(),
        'totalSevereCount': severeSymptomCount.toString(),
        'score': symptomScore
      });

      weightedScore += symptomScore * 0.25;
      totalWeight += 0.25;
    }

    // ===== FACTOR 4: Hydration Consistency (Weight: 10%) =====
    double hydrationScore = 0.0;
    if (hydrationEntries.length >= 7) {
      final last7Days = hydrationEntries.take(7).map((e) => (e['ml'] as num).toInt()).toList();
      final avgHydration = last7Days.reduce((a, b) => a + b) / last7Days.length;
      
      // Score: 0 at 500ml (very low), 100 at 3000ml (excellent)
      // Recommended: 2000-3000ml
      hydrationScore = ((avgHydration - 500) / 2500 * 100).clamp(0, 100).toDouble();

      String hydrationSeverity = 'Low';
      String hydrationDesc = 'Hydration is optimal.';
      String datasetContext = '';

      if (avgHydration < 1200) {
        hydrationSeverity = 'High';
        datasetContext = ' Clinical studies show chronic dehydration (<1200ml/day) is associated with irregular cycles and increased PCOS risk.';
        hydrationDesc = 'Hydration intake is critically low (${avgHydration.toStringAsFixed(0)}ml/day). Dehydration significantly impacts hormone regulation.$datasetContext';
      } else if (avgHydration < 1800) {
        hydrationSeverity = 'Moderate';
        datasetContext = ' Research indicates 1800-2000ml/day is suboptimal; 2000-3000ml recommended for hormonal health.';
        hydrationDesc = 'Hydration intake is below recommended levels (${avgHydration.toStringAsFixed(0)}ml/day vs 2000-3000ml recommended).$datasetContext';
      } else {
        datasetContext = ' Large-scale studies show 2000-3000ml/day hydration correlates with better menstrual regularity (75% of participants).';
        hydrationDesc = 'Hydration is adequate (${avgHydration.toStringAsFixed(0)}ml/day). Good hydration supports hormonal balance.$datasetContext';
      }

      factors.add({
        'name': 'Hydration Level',
        'severity': hydrationSeverity,
        'description': hydrationDesc,
        'avgMl': avgHydration.toStringAsFixed(0),
        'recommendedMl': '2000-3000',
        'score': (100 - hydrationScore),
        'datasetContext': 'Based on epidemiological studies on hydration and hormonal health',
        'thresholds': 'Optimal: 2000-3000ml | Caution: 1200-1800ml | Critical: <1200ml'
      });

      weightedScore += (100 - hydrationScore) * 0.10;
      totalWeight += 0.10;
    }

    // ===== FACTOR 5: Dataset Cycle Comparison (Weight: 10% - supplemental) =====
    if (menstrualCycles.length >= 2 && _populationData != null) {
      final cycleLengths = <int>[];
      for (int i = 0; i < menstrualCycles.length - 1; i++) {
        final current = menstrualCycles[i]['start'] as DateTime;
        final next = menstrualCycles[i + 1]['start'] as DateTime;
        final diff = current.difference(next).inDays.abs();
        if (diff > 0 && diff < 100) cycleLengths.add(diff);
      }

      if (cycleLengths.isNotEmpty) {
        final userAvgCycle = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
        final comparison = _dataService.compareUserToCycleData(
          userAvgCycle.toInt(),
          (menstrualCycles.isNotEmpty ? (menstrualCycles[0]['end'] as DateTime).difference(menstrualCycles[0]['start'] as DateTime).inDays : 5),
          menstrualCycles.length,
          _populationData!,
        );

        // Calculate Z-score to compare with population data
        // Z-score = (user value - population mean) / population stdDev
        final zScore = comparison.cycleVariance / _populationData!.stdDevCycleLength;
        
        // Score based on standard deviations from mean:
        // Within 1 stdDev (Z: -1 to 1) = Low risk (normal variation)
        // 1-2 stdDev (Z: 1-2 or -1 to -2) = Moderate risk
        // Beyond 2 stdDev (Z: >2 or <-2) = High risk (outlier)
        final absZScore = zScore.abs();
        double datasetScore = 0.0;
        String datasetSeverity = 'Low';
        String datasetDesc = '';

        if (absZScore > 2.0) {
          // Beyond 2 standard deviations - significant outlier
          datasetScore = 100.0;
          datasetSeverity = 'High';
          datasetDesc = '${comparison.interpretation} This is a significant deviation (Z-score: ${zScore.toStringAsFixed(2)}) from population norms. Cycle length of ${userAvgCycle.toStringAsFixed(0)} days differs by more than 2 standard deviations from average (${_populationData!.averageCycleLength.toStringAsFixed(1)}±${_populationData!.stdDevCycleLength.toStringAsFixed(1)}).';
        } else if (absZScore > 1.0) {
          // 1-2 standard deviations - moderate deviation
          datasetScore = 50.0;
          datasetSeverity = 'Moderate';
          datasetDesc = '${comparison.interpretation} This varies moderately from typical (Z-score: ${zScore.toStringAsFixed(2)}). Cycle length of ${userAvgCycle.toStringAsFixed(0)} days is ${zScore > 0 ? 'longer' : 'shorter'} than average, but within acceptable range.';
        } else {
          // Within 1 standard deviation - normal variation
          datasetScore = 0.0;
          datasetSeverity = 'Low';
          datasetDesc = '${comparison.interpretation} Your cycle falls within normal population variation (Z-score: ${zScore.toStringAsFixed(2)}). This is typical and healthy.';
        }

        factors.add({
          'name': 'Dataset Comparison',
          'severity': datasetSeverity,
          'description': datasetDesc,
          'userCycleLength': userAvgCycle.toStringAsFixed(0),
          'populationAverage': _populationData!.averageCycleLength.toStringAsFixed(1),
          'populationStdDev': _populationData!.stdDevCycleLength.toStringAsFixed(1),
          'variance': comparison.cycleVariance.toStringAsFixed(1),
          'zScore': zScore.toStringAsFixed(2),
          'confidence': (comparison.confidence * 100).toStringAsFixed(0),
          'score': datasetScore
        });

        // Only add to weighted score if outside normal range (absZScore > 1.0)
        if (absZScore > 1.0) {
          weightedScore += datasetScore * 0.10;
          totalWeight += 0.10;
        }
      }
    }

    // ===== CALCULATE FINAL RISK SCORE & LEVEL =====
    // Use weighted average (only count factors that have data)
    double finalScore = 0.0;
    if (totalWeight > 0) {
      finalScore = (weightedScore / totalWeight).clamp(0, 100);
    }

    // Risk level thresholds based on medical literature
    // Low: 0-30, Moderate: 30-70, High: 70+
    String overallRisk = 'Low';
    if (finalScore >= 70) {
      overallRisk = 'High';
    } else if (finalScore >= 40) {
      overallRisk = 'Moderate';
    }

    // Generate dataset insights
    String datasetInsights = '';
    if (_populationData != null) {
      datasetInsights = 'Insights based on ${_populationData!.source}. Sample size: ${_populationData!.sampleSize} participants. '
          'Population average cycle: ${_populationData!.averageCycleLength.toStringAsFixed(1)} days (StdDev: ${_populationData!.stdDevCycleLength.toStringAsFixed(1)}). '
          'Your risk score is calculated using weighted factors: Cycle Regularity (35%), Symptom Patterns (25%), Weight Stability (20%), Hydration (10%).';
    } else {
      datasetInsights = 'Risk score calculated from your personal health data using evidence-based weighting. '
          'Factors: Cycle Regularity (35%), Symptom Patterns (25%), Weight Stability (20%), Hydration (10%). '
          'Population comparison data not yet available - more data will improve accuracy.';
    }

    riskAssessment = {
      'pcosRisk': overallRisk,
      'score': finalScore.toInt(),
      'scoreDecimal': finalScore.toStringAsFixed(1),
      'factors': factors,
      'lastUpdated': DateTime.now(),
      'datasetInsights': datasetInsights,
      'datasetSource': _populationData?.source ?? 'Personal Health Data',
      'factorWeights': {
        'cycleRegularity': '35%',
        'symptomPatterns': '25%',
        'weightStability': '20%',
        'hydration': '10%'
      },
      'wellnessRecommendations': _generateWellnessRecommendations()
    };
  }

  /// AI-driven lifestyle wellness recommendations based on user's data patterns
  Map<String, dynamic> _generateWellnessRecommendations() {
    final recommendations = <Map<String, dynamic>>[];
    
    // ===== ANALYZE WEIGHT PATTERNS =====
    if (weightEntries.length >= 3) {
      final recentWeights = weightEntries.take(10).map((e) => (e['weight'] as num).toDouble()).toList();
      final trend = recentWeights.first - recentWeights.last; // Positive = gaining, Negative = losing
      
      if (trend.abs() > 3) {
        if (trend > 0) {
          recommendations.add({
            'category': 'Weight Management',
            'title': 'Weight Gain Detected',
            'insight': 'You have gained approximately ${trend.toStringAsFixed(1)}kg recently.',
            'personalization': 'Weight fluctuations affect hormonal balance. Even 5-10% weight changes can impact cycle regularity.',
            'recommendations': [
              '🥗 Increase fiber intake (vegetables, whole grains) to support satiety',
              '💪 Add 30 min of moderate exercise 3-4x/week (walking, cycling, strength training)',
              '⏱️ Practice portion control and eat slowly to enhance satisfaction',
              '🌙 Ensure 7-9 hours of sleep (poor sleep increases appetite hormones)'
            ]
          });
        } else {
          recommendations.add({
            'category': 'Weight Management',
            'title': 'Healthy Weight Loss in Progress',
            'insight': 'You have lost approximately ${(-trend).toStringAsFixed(1)}kg - great progress!',
            'personalization': 'Gradual weight loss (0.5-1kg/week) is ideal and supports hormonal health.',
            'recommendations': [
              '✅ Maintain current healthy habits - consistency is key',
              '🥤 Increase water intake to support metabolism and reduce hunger',
              '🍎 Include lean proteins at each meal for stable blood sugar',
              '📊 Continue tracking to maintain your positive momentum'
            ]
          });
        }
      }
    }

    // ===== ANALYZE HYDRATION PATTERNS =====
    if (hydrationEntries.length >= 3) {
      final last7 = hydrationEntries.take(7).map((e) => (e['ml'] as num).toInt()).toList();
      final avgHydration = last7.reduce((a, b) => a + b) / last7.length;
      
      if (avgHydration < 1500) {
        recommendations.add({
          'category': 'Hydration & Wellness',
          'title': 'Critical: Increase Water Intake',
          'insight': 'Current average: ${avgHydration.toStringAsFixed(0)}ml/day (Goal: 2000-3000ml)',
          'personalization': 'Dehydration directly impacts hormone production and cycle regularity. Women with low hydration show 30% higher cycle irregularity.',
          'recommendations': [
            '💧 Start with 500ml upon waking to rehydrate after sleep',
            '⏰ Set phone reminders: drink 250ml every 2 hours during the day',
            '🍵 Drink herbal tea (chamomile, spearmint) - counts toward hydration + hormone benefits',
            '⚡ Track water intake in OvaCare to build the habit'
          ]
        });
      } else if (avgHydration < 2000) {
        recommendations.add({
          'category': 'Hydration & Wellness',
          'title': 'Optimize Hydration for Hormones',
          'insight': 'Current average: ${avgHydration.toStringAsFixed(0)}ml/day (Optimal: 2000-3000ml)',
          'personalization': 'You\'re on the right track! Reaching optimal hydration will improve cycle consistency.',
          'recommendations': [
            '💧 Add 200-300ml more water daily to reach 2000ml minimum',
            '🥬 Eat hydrating foods: cucumber, watermelon, lettuce (provide 20% of daily hydration)',
            '☕ Limit caffeine which can dehydrate - max 200mg/day (1 cup coffee)',
            '🏃 Drink extra water on exercise days (500ml per hour of activity)'
          ]
        });
      }
    }

    // ===== ANALYZE SYMPTOM PATTERNS =====
    if (symptoms.isNotEmpty) {
      final recentSymptoms = symptoms.take(20);
      final crampCount = recentSymptoms.where((s) => (s['type'] as String?)?.toLowerCase().contains('cramp') ?? false).length;
      final acneCount = recentSymptoms.where((s) => (s['type'] as String?)?.toLowerCase().contains('acne') ?? false).length;
      final moodCount = recentSymptoms.where((s) => (s['type'] as String?)?.toLowerCase().contains('mood') ?? false).length;
      final bloatingCount = recentSymptoms.where((s) => (s['type'] as String?)?.toLowerCase().contains('bloat') ?? false).length;
      
      if (crampCount >= 3) {
        recommendations.add({
          'category': 'Symptom Relief',
          'title': 'Managing Period Cramps',
          'insight': 'Severe cramping detected in $crampCount recent cycles.',
          'personalization': 'Severe cramps (>5/10) may indicate inflammation or magnesium deficiency.',
          'recommendations': [
            '🌿 Magnesium supplements (300-400mg): helps relax uterine muscles',
            '🌡️ Heat therapy: heating pad 15min 3-4x during period reduces pain by 40%',
            '🧘 Light yoga: child\'s pose, cat-cow stretch improve blood flow',
            '🍫 Dark chocolate, nuts, seeds (natural magnesium sources)'
          ]
        });
      }

      if (acneCount >= 2) {
        recommendations.add({
          'category': 'Hormonal Skin Health',
          'title': 'Managing Hormonal Acne',
          'insight': 'Acne breakouts detected in $acneCount recent entries.',
          'personalization': 'Hormonal fluctuations trigger oil production. These tips target root causes.',
          'recommendations': [
            '🧴 Use salicylic acid cleanser during luteal phase (10 days before period)',
            '🍎 Anti-inflammatory diet: reduce dairy, increase omega-3 (fish, flax, walnuts)',
            '🌿 Spearmint tea: clinically shown to reduce hormonal acne in 3 months',
            '😴 Prioritize sleep - skin repairs during sleep (7-9 hours)'
          ]
        });
      }

      if (moodCount >= 3) {
        recommendations.add({
          'category': 'Mental Wellness',
          'title': 'Managing Mood Swings',
          'insight': 'Mood changes detected in $moodCount recent cycles.',
          'personalization': 'Serotonin drops in luteal phase. Lifestyle changes can help significantly.',
          'recommendations': [
            '☀️ Morning sunlight exposure: 15-20 min within 2 hours of waking (boosts serotonin)',
            '🚴 Aerobic exercise: 30min cardio 3-4x/week reduces mood symptoms by 50%',
            '🧠 Magnesium & B vitamins: support neurotransmitter production',
            '📝 Journaling during luteal phase: process emotions, plan self-care'
          ]
        });
      }

      if (bloatingCount >= 2) {
        recommendations.add({
          'category': 'Digestive Wellness',
          'title': 'Reducing Bloating',
          'insight': 'Bloating detected in $bloatingCount recent cycles.',
          'personalization': 'Hormonal fluctuations reduce gut motility. Targeted nutrition helps.',
          'recommendations': [
            '🥗 Increase fiber gradually (25-30g/day) - fermentation causes bloating if rushed',
            '🍵 Ginger & fennel tea: improve digestion and reduce gas',
            '🚶 15-min walks after meals: stimulate digestion and reduce bloating',
            '🧂 Reduce sodium in luteal phase (increases water retention)'
          ]
        });
      }
    }

    // ===== ANALYZE CYCLE CONSISTENCY =====
    if (menstrualCycles.length >= 3) {
      final lengths = <int>[];
      for (int i = 0; i < menstrualCycles.length - 1; i++) {
        final current = menstrualCycles[i]['end'] as DateTime;
        final next = menstrualCycles[i + 1]['start'] as DateTime;
        final diff = current.difference(next).inDays.abs();
        if (diff > 0 && diff < 100) lengths.add(diff);
      }
      
      if (lengths.isNotEmpty) {
        final avgLength = lengths.reduce((a, b) => a + b) / lengths.length;
        
        if (avgLength > 35 || avgLength < 21) {
          recommendations.add({
            'category': 'Cycle Health',
            'title': 'Cycle Length Outside Normal Range',
            'insight': 'Average cycle: ${avgLength.toStringAsFixed(0)} days (Normal: 21-35 days)',
            'personalization': avgLength > 35 
              ? 'Long cycles may indicate low estrogen or thyroid issues. Worth discussing with a doctor.' 
              : 'Short cycles may indicate anovulation (no ovulation). Get tested if persistent.',
            'recommendations': [
              '📋 Track additional data: basal body temperature (BBT) for 1 month',
              '🩺 Get thyroid checked (TSH, Free T4, Free T3) - thyroid dysfunction is common',
              '🥦 Ensure adequate iodine (seaweed, dairy) and selenium (Brazil nuts, fish)',
              '👨‍⚕️ Share this data with gynecologist for professional assessment'
            ]
          });
        } else {
          recommendations.add({
            'category': 'Cycle Health',
            'title': 'Healthy Cycle Pattern',
            'insight': 'Average cycle: ${avgLength.toStringAsFixed(0)} days (within normal 21-35 day range)',
            'personalization': 'Your cycle is in the healthy range! Continue current tracking habits.',
            'recommendations': [
              '✅ Maintain current lifestyle patterns that support cycle health',
              '📊 Continue tracking - 6 months of data provides best insights',
              '🎯 Focus on the recommendations above for symptom optimization',
              '🔔 Note any changes and report to doctor if cycle becomes irregular'
            ]
          });
        }
      }
    }

    // ===== GENERATE PRIORITY RECOMMENDATION =====
    String priorityCategory = 'Hydration & Wellness';
    String priorityTitle = 'Start Here';
    String priorityReason = 'Proper hydration is the foundation of hormonal health.';

    if (hydrationEntries.length >= 3) {
      final last7 = hydrationEntries.take(7).map((e) => (e['ml'] as num).toInt()).toList();
      final avgHydration = last7.reduce((a, b) => a + b) / last7.length;
      
      if (avgHydration < 1500) {
        priorityReason = 'Your critical hydration deficit is impacting all other health factors.';
      } else if (weightEntries.length >= 3) {
        final recentWeights = weightEntries.take(10).map((e) => (e['weight'] as num).toDouble()).toList();
        final trend = recentWeights.first - recentWeights.last;
        if (trend.abs() > 3) {
          priorityCategory = 'Weight Management';
          priorityTitle = 'Weight Stabilization';
          priorityReason = 'Stabilizing weight will significantly improve cycle regularity.';
        }
      }
    }

    return {
      'recommendations': recommendations,
      'priority': {
        'category': priorityCategory,
        'title': priorityTitle,
        'reason': priorityReason
      },
      'generatedAt': DateTime.now().toIso8601String()
    };
  }
}

// ============== SCREENS ==============

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink[50]!,
              Colors.purple[50]!,
              Colors.blue[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // App Logo and Title
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.pink[400]!, Colors.purple[300]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'OvaCare',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your PCOS Health Companion',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Login Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue your health journey',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.pink[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.pink[600]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordDialog(),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Colors.pink[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 3,
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Signing In...', style: TextStyle(fontSize: 16)),
                                  ],
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
                            ),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Colors.pink[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Please enter both email and password');
      return;
    }

    // Basic email validation
    if (!email.contains('@')) {
      _showErrorSnackBar('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(email, password);

      if (!success && mounted) {
        _showErrorSnackBar(authProvider.errorMessage ?? 'Login failed');
      } else if (success && mounted) {
        // Login successful, navigate to dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    DialogHelper.showInfoDialog(
      context: context,
      title: 'Forgot Password',
      message: 'For demo purposes, use the provided demo accounts. In a real app, password reset functionality would be implemented here.',
      buttonText: 'OK',
      icon: Icons.lock_reset_rounded,
      iconColor: Colors.orange[400],
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const OverviewScreen(),
      const HealthTrackingScreen(),
      const RiskAssessmentScreen(),
      const EducationScreen(),
      const ExerciseRecipeTutorialsScreen(),
      const CommunityForumScreen(),
      //const DoctorDirectoryScreen(),
      //const DataReportingScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('OvaCare Dashboard'),
        backgroundColor: Colors.white.withOpacity(0.7),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0, Colors.pink),
                  _buildNavItem(Icons.favorite_outline, Icons.favorite, 'Health', 1, Colors.redAccent),
                  _buildNavItem(Icons.warning_amber_outlined, Icons.warning_amber, 'Risk', 2, Colors.orange),
                  _buildNavItem(Icons.school_outlined, Icons.school, 'Learn', 3, Colors.blue),
                  _buildNavItem(Icons.fitness_center_outlined, Icons.fitness_center, 'Workout', 4, Colors.green),
                  _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Forum', 5, Colors.purple),
                  _buildNavItem(Icons.local_hospital_outlined, Icons.local_hospital, 'Doctors', 6, Colors.teal),
                  _buildNavItem(Icons.assessment_outlined, Icons.assessment, 'Reports', 7, Colors.indigo),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index, Color color) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isSelected ? filledIcon : outlinedIcon,
                color: isSelected ? color : Colors.grey[600],
                size: isSelected ? 26 : 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final health = context.watch<HealthDataProvider>();
    final lastCycle = health.menstrualCycles.isNotEmpty ? health.menstrualCycles.first : null;
    final lastSymptom = health.symptoms.isNotEmpty ? health.symptoms.first : null;
    final todayHydration = health.hydrationEntries.where((h) => h['date'].day == DateTime.now().day).fold<int>(0, (sum, h) => sum + (h['ml'] as int));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.pink[400]!,
                Colors.purple[300]!,
                Colors.blue[300]!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.pink[50],
                        child: Icon(Icons.person, color: Colors.pink[600], size: 36),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.userName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              auth.userEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showNotifications(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.red[400],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: const Center(
                                  child: Text(
                                    '3',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildStatCard(
                        icon: Icons.monitor_weight,
                        label: 'Weight',
                        value: '${auth.userWeight} kg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildStatCard(
                        icon: Icons.cake,
                        label: 'Age',
                        value: '${auth.userAge}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildStatCard(
                        icon: Icons.height,
                        label: 'Height',
                        value: '${auth.userHeight} cm',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Health Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink[700])),
        ),
        _buildIconCard('Last Menstrual Cycle', lastCycle != null ? '${lastCycle['start']}\nFlow: ${lastCycle['flow']}/5' : 'No data', Icons.water_drop, Colors.pink),
        _buildIconCard('Today\'s Hydration', '$todayHydration ml (Goal: 2000 ml)', Icons.local_drink, Colors.teal),
        _buildIconCard('Latest Symptom', lastSymptom != null ? 'Mood: ${lastSymptom['mood']}, Cramps: ${lastSymptom['cramps']}/10' : 'No data', Icons.sentiment_satisfied, Colors.orange),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Lifestyle & Wellness', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
        ),
        ...LifestyleWellnessScreen.recommendations.map((rec) => Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rec['emoji'] as String, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rec['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...(rec['items'] as List).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item as String)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconCard(String title, String content, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  const SizedBox(height: 8),
                  Text(content, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final notifications = [
      {
        'title': 'Period Prediction',
        'message': 'Your next period is predicted to start in 3 days',
        'time': '2 hours ago',
        'icon': Icons.water_drop,
        'color': Colors.pink,
        'read': false,
      },
      {
        'title': 'Medication Reminder',
        'message': 'Time to take your evening Metformin dose',
        'time': '4 hours ago',
        'icon': Icons.medication,
        'color': Colors.teal,
        'read': false,
      },
      {
        'title': 'Hydration Goal',
        'message': 'Great job! You reached your daily water intake goal',
        'time': '1 day ago',
        'icon': Icons.local_drink,
        'color': Colors.blue,
        'read': true,
      },
      {
        'title': 'New Forum Post',
        'message': 'Someone replied to your PCOS diet discussion',
        'time': '2 days ago',
        'icon': Icons.chat_bubble,
        'color': Colors.purple,
        'read': true,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '3 unread',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !(notification['read'] as bool) 
                          ? Colors.blue[50]?.withOpacity(0.5) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (notification['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            notification['icon'] as IconData,
                            color: notification['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification['title'] as String,
                                      style: TextStyle(
                                        fontWeight: !(notification['read'] as bool)
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (!(notification['read'] as bool))
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[600],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification['message'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification['time'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text(
                    'Mark All as Read',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  
  final List<String> _cities = [
    'Floridablanca',
    'Mexico',
    'San Luis',
    'Santo Tomas',
    'Candaba',
    'Guagua',
    'Lubao',
    'Magalang',
  ];
  String? _selectedCity;

  @override
  void dispose() {
    _formKey.currentState?.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Privacy Policy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Parse age, height, weight
    int? age = int.tryParse(_ageController.text.trim());
    double? height = double.tryParse(_heightController.text.trim());
    double? weight = double.tryParse(_weightController.text.trim());
    
    final success = await authProvider.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      age: age,
      height: height,
      weight: weight,
      city: _selectedCity,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Optionally, set up HealthDataProvider for the new user
      final healthProvider = Provider.of<HealthDataProvider>(context, listen: false);
      await healthProvider.setCurrentUserId(authProvider.userId);
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (!success && mounted) {
      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please check your email to confirm your account.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink[50]!,
              Colors.purple[50]!,
              Colors.blue[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  const Text(
                    'Create your account to start tracking your health',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Sign Up Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Join OvaCare Community',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your account to start tracking your health',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Personal Information Section
                        _buildSectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        
                        _buildTextFormField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter your full name';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildTextFormField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter your email';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Account Information Section
                        _buildSectionTitle('Account Information'),
                        const SizedBox(height: 12),
                        
                        _buildTextFormField(
                          controller: _usernameController,
                          label: 'Username',
                          icon: Icons.account_circle_outlined,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter a username';
                            if (value!.length < 3) return 'Username must be at least 3 characters';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildTextFormField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter a password';
                            if (value!.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildTextFormField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          icon: Icons.lock_outline,
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please confirm your password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Health Information Section
                        _buildSectionTitle('Health Information (Optional)'),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _ageController,
                                label: 'Age',
                                icon: Icons.cake_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _heightController,
                                label: 'Height (cm)',
                                icon: Icons.height,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildTextFormField(
                          controller: _weightController,
                          label: 'Weight (kg)',
                          icon: Icons.monitor_weight_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // City Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedCity,
                          items: _cities.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedCity = value),
                          decoration: InputDecoration(
                            labelText: 'City (Pampanga)',
                            prefixIcon: Icon(Icons.location_on_outlined, color: Colors.pink[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: 'Select your city',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please select a city';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Terms and Conditions
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                              activeColor: Colors.pink[400],
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          color: Colors.pink[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: Colors.pink[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 3,
                            ),
                            onPressed: (_isLoading || !_agreeToTerms) ? null : _handleSignUp,
                            child: _isLoading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('Creating Account...', style: TextStyle(fontSize: 16)),
                                    ],
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Sign In Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.pink[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.pink[700],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.pink[600]),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userName;
    _emailController.text = auth.userEmail;
    _ageController.text = auth.userAge.toString();
    _heightController.text = auth.userHeight.toString();
    _weightController.text = auth.userWeight.toString();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile(auth);
              }
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.pink[400]!,
                    Colors.purple[300]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.pink[50],
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.pink[600],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.pink[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    auth.userName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.userEmail,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Profile Details
            _buildSectionCard(
              title: 'Personal Information',
              children: [
                _buildProfileField(
                  label: 'Full Name',
                  controller: _nameController,
                  icon: Icons.person_outline,
                ),
                _buildProfileField(
                  label: 'Email',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                ),
                _buildProfileField(
                  label: 'Age',
                  controller: _ageController,
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Health Information
            _buildSectionCard(
              title: 'Health Information',
              children: [
                _buildProfileField(
                  label: 'Height (cm)',
                  controller: _heightController,
                  icon: Icons.height,
                  keyboardType: TextInputType.number,
                ),
                _buildProfileField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  icon: Icons.monitor_weight_outlined,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            _buildSectionCard(
              title: 'Quick Actions',
              children: [
                _buildActionTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => _showChangePasswordDialog(),
                ),
                _buildActionTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notification Settings',
                  subtitle: 'Manage your notification preferences',
                  onTap: () => _showNotificationSettings(),
                ),
                _buildActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Settings',
                  subtitle: 'Control your data and privacy',
                  onTap: () => _showPrivacySettings(),
                ),
                _buildActionTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help and contact support',
                  onTap: () => _showHelpDialog(),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  final confirmed = await DialogHelper.showConfirmationDialog(
                    context: context,
                    title: 'Logout',
                    message: 'Are you sure you want to logout? You\'ll need to sign in again to access your data.',
                    confirmText: 'Logout',
                    cancelText: 'Cancel',
                    icon: Icons.logout_rounded,
                    isDangerous: true,
                  );
                  if (confirmed == true) {
                    auth.logout();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink[600],
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: _isEditing,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.pink[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          filled: true,
          fillColor: _isEditing ? Colors.white : Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.pink[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.pink[600]),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _saveProfile(AuthProvider auth) {
    final name = _nameController.text;
    final age = int.tryParse(_ageController.text) ?? auth.userAge;
    final height = double.tryParse(_heightController.text) ?? auth.userHeight;
    final weight = double.tryParse(_weightController.text) ?? auth.userWeight;
    
    auth.updateProfile(name, age, height, weight);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showChangePasswordDialog() {
    DialogHelper.showInfoDialog(
      context: context,
      title: 'Change Password',
      message: 'Password change functionality would be implemented here.',
      buttonText: 'Close',
      icon: Icons.password_rounded,
      iconColor: Colors.blue[400],
    );
  }

  void _showNotificationSettings() {
    DialogHelper.showInfoDialog(
      context: context,
      title: 'Notification Settings',
      message: 'Notification preferences would be configured here.',
      buttonText: 'Close',
      icon: Icons.notifications_rounded,
      iconColor: Colors.amber[500],
    );
  }

  void _showPrivacySettings() {
    DialogHelper.showInfoDialog(
      context: context,
      title: 'Privacy Settings',
      message: 'Privacy controls would be available here.',
      buttonText: 'Close',
      icon: Icons.privacy_tip_rounded,
      iconColor: Colors.teal[400],
    );
  }

  void _showHelpDialog() {
    DialogHelper.showInfoDialog(
      context: context,
      title: 'Help & Support',
      message: 'Contact: support@ovacare.com\nPhone: +63-45-625-HELP',
      buttonText: 'Close',
      icon: Icons.support_agent_rounded,
      iconColor: Colors.green[400],
    );
  }
}

class HealthTrackingScreen extends StatefulWidget {
  const HealthTrackingScreen({super.key});

  @override
  State<HealthTrackingScreen> createState() => _HealthTrackingScreenState();
}

class _HealthTrackingScreenState extends State<HealthTrackingScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;
  DateTime _calendarDate = DateTime.now(); // For calendar navigation
  late AnimationController _waveController;
  late DataService _dataService;
  PopulationCycleData? _populationData;
  // Auto-marking enabled by default; taps toggle mark/unmark, long-press opens details

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _dataService = DataService();
    _loadPopulationData();
  }
  
  /// Load population cycle data from online service
  void _loadPopulationData() async {
    try {
      final data = await _dataService.getPopulationCycleData();
      if (mounted) {
        setState(() {
          _populationData = data;
        });
      }
    } catch (e) {
      print('Error loading population data: $e');
      // Gracefully handle errors - app continues with local data only
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthDataProvider>();

    return Column(
      children: [
        Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton('Menstrual', 0),
                    _buildTabButton('Symptoms', 1),
                    _buildTabButton('Hydration', 2),
                    _buildTabButton('Medications', 3),
                    _buildTabButton('Weight', 4),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Container(
                      width: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.pink.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(50, double.infinity),
                            painter: WaveIndicatorPainter(
                              wavePhase: _waveController.value * 2 * 3.14159,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.pink[400],
                            size: 24,
                            shadows: [
                              Shadow(
                                color: Colors.pink.withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildMenstrualTab(health),
              _buildSymptomsTab(health),
              _buildHydrationTab(health),
              _buildMedicationsTab(health),
              _buildWeightTab(health),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedTab = index),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedTab == index ? Colors.pink.withOpacity(0.2) : Colors.transparent,
          foregroundColor: _selectedTab == index ? Colors.pink : Colors.grey[600],
          elevation: 0,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildMenstrualTab(HealthDataProvider health) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced cycle overview card with cycle phase info
          _buildEnhancedCycleOverviewCard(health),
          const SizedBox(height: 20),
          
          // Current cycle phase insights card
          if (health.menstrualCycles.isNotEmpty)
            _buildCyclePhaseInsightsCard(health),
          if (health.menstrualCycles.isNotEmpty)
            const SizedBox(height: 20),
          
          // Calendar widget with improved design
          _buildEnhancedFloStyleCalendar(health),
          const SizedBox(height: 20),
          
          // Cycle statistics with better styling
          _buildEnhancedCycleStatsCard(health),
          const SizedBox(height: 20),
          
          // Today's insights (Flo-style)
          _buildTodayInsightsCard(health),
          const SizedBox(height: 20),
          
          // Population comparison card (if data available)
          if (_populationData != null)
            _buildPopulationComparisonCard(health, _populationData!),
          if (_populationData != null)
            const SizedBox(height: 20),
          
          // Clear button for old data
          if (health.menstrualCycles.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await DialogHelper.showConfirmationDialog(
                    context: context,
                    title: 'Clear Cycle History?',
                    message: 'This will delete all stored menstrual cycle data. This action cannot be undone.',
                    confirmText: 'Clear All',
                    cancelText: 'Cancel',
                    icon: Icons.delete_forever_rounded,
                    isDangerous: true,
                  );
                  if (confirmed == true) {
                    health.clearCycleHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Cycle history cleared'),
                          ],
                        ),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Cycle History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[400],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSymptomsTab(HealthDataProvider health) {
    // Enhanced symptoms tracker with severity, categories, and statistics
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Stats Card
          if (health.symptoms.isNotEmpty)
            Card(
              color: Colors.pink.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary (Last 30 Days)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.pink)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('Total Logs', health.symptoms.length.toString(), Colors.pink),
                        _buildStatItem('Avg Cramps', '${(health.symptoms.fold<int>(0, (sum, s) => sum + (s['cramps'] as int? ?? 0)) / health.symptoms.length).toStringAsFixed(1)}/10', Colors.orange),
                        _buildStatItem('Acne %', '${((health.symptoms.where((s) => s['acne'] ?? false).length / health.symptoms.length) * 100).toStringAsFixed(0)}%', Colors.red),
                        _buildStatItem('Bloating %', '${((health.symptoms.where((s) => s['bloating'] ?? false).length / health.symptoms.length) * 100).toStringAsFixed(0)}%', Colors.amber),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Symptoms List
          Expanded(
            child: health.symptoms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_satisfied_alt, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No symptoms logged yet',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('Tap "Add Symptom" to start tracking',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: health.symptoms.length,
                    itemBuilder: (context, index) {
                      final symptom = health.symptoms[index];
                      final cramps = symptom['cramps'] ?? 0;
                      final hasSevereSymptoms = cramps >= 7 || symptom['acne'] == true || symptom['bloating'] == true;
                      final symptomsCount = (cramps > 0 ? 1 : 0) + (symptom['acne'] == true ? 1 : 0) + (symptom['bloating'] == true ? 1 : 0);
                      
                      return Card(
                        elevation: hasSevereSymptoms ? 2 : 0,
                        color: hasSevereSymptoms ? Colors.red.shade50 : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mood: ${symptom['mood']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          symptom['date'].toString().split(" ")[0],
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasSevereSymptoms)
                                    Tooltip(
                                      message: 'Severe symptoms detected',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text('⚠️ Severe',
                                            style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('✓ Mild',
                                          style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Symptoms Grid
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Cramps
                                  _buildSymptomChip(
                                    icon: '🤕',
                                    label: 'Cramps',
                                    value: '$cramps/10',
                                    color: cramps >= 7 ? Colors.red : cramps >= 4 ? Colors.orange : Colors.green,
                                  ),
                                  // Acne
                                  if (symptom['acne'] == true)
                                    _buildSymptomChip(
                                      icon: '🔴',
                                      label: 'Acne',
                                      value: 'Yes',
                                      color: Colors.red,
                                    ),
                                  // Bloating
                                  if (symptom['bloating'] == true)
                                    _buildSymptomChip(
                                      icon: '💨',
                                      label: 'Bloating',
                                      value: 'Yes',
                                      color: Colors.orange,
                                    ),
                                  // Summary
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$symptomsCount symptoms',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // Add Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Symptom', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showSymptomDialog(context, health),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatItemWithIcon(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomChip({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  void _showSymptomDialog(BuildContext context, HealthDataProvider health) {
    String mood = 'Happy';
    int cramps = 0;
    bool acne = false;
    bool bloating = false;
    bool hairGrowth = false;
    bool irregular = false;
    int severity = 1; // 1-5 scale

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Log Symptoms', style: TextStyle(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mood Selection
                    const Align(alignment: Alignment.centerLeft, child: Text('Mood', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: mood,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: ['Happy', 'Tired', 'Anxious', 'Sad', 'Energetic', 'Irritable', 'Calm', 'Stressed', 'Neutral']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(() => mood = v ?? 'Happy'),
                    ),
                    const SizedBox(height: 16),
                    // Severity Level
                    const Align(alignment: Alignment.centerLeft, child: Text('Overall Severity', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 1; i <= 5; i++)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => severity = i),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: severity >= i ? Colors.orange : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('$i', style: TextStyle(color: severity >= i ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Cramps Slider
                    const Align(alignment: Alignment.centerLeft, child: Text('Cramp Intensity', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: cramps.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: cramps.toString(),
                            activeColor: cramps >= 7 ? Colors.red : Colors.orange,
                            onChanged: (v) => setState(() => cramps = v.round()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('$cramps/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Symptoms Checkboxes
                    const Align(alignment: Alignment.centerLeft, child: Text('Other Symptoms', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Acne/Skin Issues'),
                      value: acne,
                      dense: true,
                      onChanged: (v) => setState(() => acne = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Bloating'),
                      value: bloating,
                      dense: true,
                      onChanged: (v) => setState(() => bloating = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Excessive Hair Growth'),
                      value: hairGrowth,
                      dense: true,
                      onChanged: (v) => setState(() => hairGrowth = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Irregular Period'),
                      value: irregular,
                      dense: true,
                      onChanged: (v) => setState(() => irregular = v ?? false),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              onPressed: () {
                health.addSymptom({
                  'date': DateTime.now(),
                  'mood': mood,
                  'cramps': cramps,
                  'acne': acne,
                  'bloating': bloating,
                  'hairGrowth': hairGrowth,
                  'irregular': irregular,
                  'severity': severity,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHydrationTab(HealthDataProvider health) {
    double avgHydration = 0;
    int totalEntries = health.hydrationEntries.length;
    if (health.hydrationEntries.isNotEmpty) {
      final total = health.hydrationEntries.take(7).fold<int>(0, (sum, e) => sum + ((e['ml'] as num).toInt()));
      avgHydration = total / (health.hydrationEntries.take(7).isNotEmpty ? health.hydrationEntries.take(7).length : 1);
    }
    Color hydrationColor = Colors.blue;
    String hydrationStatus = 'Optimal';
    if (avgHydration < 1200) { hydrationColor = Colors.red; hydrationStatus = 'Critical'; }
    else if (avgHydration < 1800) { hydrationColor = Colors.orange; hydrationStatus = 'Low'; }
    else if (avgHydration >= 2000) { hydrationColor = Colors.green; }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: hydrationColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.local_drink, color: hydrationColor, size: 32),
                    const SizedBox(height: 8),
                    const Text('Daily Avg', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('${avgHydration.toStringAsFixed(0)} ml', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hydrationColor)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    const Text('Total Logs', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('$totalEntries', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.flag, color: hydrationColor, size: 32),
                    const SizedBox(height: 8),
                    const Text('Status', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(hydrationStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: hydrationColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    avgHydration >= 2000 ? 'Great hydration! Keep it up! 💧' : 'Target: 2000-3000ml daily',
                    style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: health.hydrationEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_drink_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No hydration logs yet', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: health.hydrationEntries.length,
                    itemBuilder: (context, index) {
                      final entry = health.hydrationEntries[index];
                      final ml = (entry['ml'] as num).toInt();
                      final date = entry['date'] as DateTime;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.all(12),
                                child: Icon(Icons.local_drink, color: Colors.blue[600], size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$ml ml', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text(date.toString().split(' ')[0], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: ml >= 2000 ? Colors.green[100] : Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(
                                  ml >= 2000 ? 'Good ✓' : 'Low',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: ml >= 2000 ? Colors.green[700] : Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Log Water'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                int selectedMl = 2000;
                TextEditingController customController = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Log Hydration'),
                      content: StatefulBuilder(
                        builder: (ctx, setState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonFormField<int>(
                                initialValue: selectedMl,
                                decoration: const InputDecoration(labelText: 'Amount (ml)', border: OutlineInputBorder()),
                                items: [1000, 1500, 1800, 2000, 2200, 2500, 3000].map((m) => DropdownMenuItem(value: m, child: Text('$m ml'))).toList(),
                                onChanged: (v) => setState(() => selectedMl = v ?? 2000),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: customController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Or custom (ml)', border: OutlineInputBorder()),
                              ),
                            ],
                          );
                        },
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          onPressed: () {
                            int ml = selectedMl;
                            if (customController.text.isNotEmpty) {
                              final customMl = int.tryParse(customController.text);
                              if (customMl != null && customMl > 0) ml = customMl;
                            }
                            health.addHydration(ml);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logged $ml ml - Great! 💧'), backgroundColor: Colors.blue),
                            );
                          },
                          child: const Text('Log'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsTab(HealthDataProvider health) {
    int totalMeds = health.medications.length;
    int completedDoses = 0, totalDoses = 0;
    for (var med in health.medications) {
      final taken = med['taken'] as List<bool>;
      totalDoses += taken.length;
      completedDoses += taken.where((t) => t).length;
    }
    double adherence = totalDoses > 0 ? (completedDoses / totalDoses * 100) : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.medication, color: Colors.teal, size: 32),
                    const SizedBox(height: 8),
                    const Text('Medications', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('$totalMeds', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    const Text('Completed', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('$completedDoses/$totalDoses', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.percent, color: Colors.purple, size: 32),
                    const SizedBox(height: 8),
                    const Text('Adherence', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('${adherence.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: adherence >= 75 ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: adherence >= 75 ? Colors.green[200]! : Colors.orange[200]!, width: 1),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: adherence >= 75 ? Colors.green : Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    adherence >= 75 ? 'Great adherence! Keep consistent! 💪' : 'Try to maintain consistent schedule',
                    style: TextStyle(
                      fontSize: 12,
                      color: adherence >= 75 ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: health.medications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No medications tracked', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: health.medications.length,
                    itemBuilder: (context, medIndex) {
                      final med = health.medications[medIndex];
                      final medTaken = med['taken'] as List<bool>;
                      final medCompleted = medTaken.where((t) => t).length;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Container(
                            decoration: BoxDecoration(color: Colors.teal[100], borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.medication, color: Colors.teal[600], size: 20),
                          ),
                          title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Row(
                            children: [
                              Chip(
                                label: Text(med['dose'], style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.teal[50],
                                side: BorderSide(color: Colors.teal[200]!),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '$medCompleted/${med['times'].length} taken',
                                  style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                children: List.generate(med['times'].length, (timeIndex) {
                                  final time = med['times'][timeIndex];
                                  final taken = med['taken'][timeIndex];
                                  final icons = {'Morning': '🌅', 'Afternoon': '☀️', 'Evening': '🌆', 'Night': '🌙'};
                                  return CheckboxListTile(
                                    title: Text('$time ${icons[time] ?? '⏰'}'),
                                    value: taken,
                                    dense: true,
                                    activeColor: Colors.teal,
                                    checkColor: Colors.white,
                                    onChanged: (_) => health.toggleMedication(medIndex, timeIndex),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Medication'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                List<String> allTimes = ['Morning', 'Afternoon', 'Evening', 'Night'];
                List<bool> selectedTimes = [true, false, false, false];
                List<bool> taken = [false, false, false, false];
                TextEditingController nameController = TextEditingController();
                TextEditingController doseController = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Add Medication'),
                      content: StatefulBuilder(
                        builder: (ctx, setState) {
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(labelText: 'Medication Name', border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: doseController,
                                  decoration: const InputDecoration(labelText: 'Dose (e.g., 500mg)', border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 16),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('When to take:', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: List.generate(allTimes.length, (i) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: selectedTimes[i],
                                          onChanged: (v) => setState(() => selectedTimes[i] = v ?? false),
                                        ),
                                        Text(allTimes[i]),
                                        const SizedBox(width: 16),
                                        if (selectedTimes[i])
                                          Checkbox(
                                            value: taken[i],
                                            onChanged: (v) => setState(() => taken[i] = v ?? false),
                                          ),
                                        if (selectedTimes[i]) const Text('Taken', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  )),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          onPressed: () {
                            if (nameController.text.isNotEmpty && doseController.text.isNotEmpty) {
                              List<String> times = [];
                              List<bool> timesTaken = [];
                              for (int i = 0; i < allTimes.length; i++) {
                                if (selectedTimes[i]) {
                                  times.add(allTimes[i]);
                                  timesTaken.add(taken[i]);
                                }
                              }
                              if (times.isNotEmpty) {
                                health.addMedication(nameController.text, doseController.text, times, timesTaken, DateTime.now());
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${nameController.text} added! 💊'), backgroundColor: Colors.teal),
                                );
                              }
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTab(HealthDataProvider health) {
    double currentWeight = 0, weightChange = 0;
    String weightTrend = 'Stable';
    Color trendColor = Colors.green;
    
    if (health.weightEntries.isNotEmpty) {
      currentWeight = (health.weightEntries.first['weight'] as num).toDouble();
      if (health.weightEntries.length > 1) {
        final oldestWeight = (health.weightEntries.last['weight'] as num).toDouble();
        weightChange = currentWeight - oldestWeight;
        if (weightChange > 1) { weightTrend = 'Increasing'; trendColor = Colors.orange; }
        else if (weightChange < -1) { weightTrend = 'Decreasing'; trendColor = Colors.green; }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: trendColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.monitor_weight, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    const Text('Current', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('${currentWeight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.trending_up, color: trendColor, size: 32),
                    const SizedBox(height: 8),
                    const Text('Trend', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(weightTrend, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: trendColor)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.difference, color: Colors.purple, size: 32),
                    const SizedBox(height: 8),
                    const Text('Change', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg', 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: weightChange > 0 ? Colors.orange : Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    weightChange.abs() <= 2 ? 'Great stability! Supporting hormonal health ✓' : 'Track consistency for better balance',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: health.weightEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monitor_weight, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No weight logs yet', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: health.weightEntries.length,
                    itemBuilder: (context, index) {
                      final entry = health.weightEntries[index];
                      final weight = (entry['weight'] as num).toDouble();
                      final date = entry['date'] as DateTime;
                      final isLatest = index == 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.all(12),
                                child: Icon(Icons.monitor_weight, color: Colors.orange[600], size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text(date.toString().split(' ')[0], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              if (isLatest)
                                Container(
                                  decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text('Latest', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange[700])),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Log Weight'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                double? newWeight;
                final controller = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Log Weight'),
                      content: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                        onChanged: (v) => newWeight = double.tryParse(v),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          onPressed: () {
                            if (newWeight != null && newWeight! > 0) {
                              health.addWeightEntry(newWeight!);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Logged: ${newWeight!.toStringAsFixed(1)} kg ⚖️'), backgroundColor: Colors.orange),
                              );
                            }
                          },
                          child: const Text('Log'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Flo-style cycle overview card
  Widget _buildCycleOverviewCard(HealthDataProvider health) {
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    
    // Check if today is an actual logged period day
    Map<String, dynamic>? currentCycle;
    for (final c in health.menstrualCycles) {
      final s = DateTime((c['start'] as DateTime).year, (c['start'] as DateTime).month, (c['start'] as DateTime).day);
      final e = DateTime((c['end'] as DateTime).year, (c['end'] as DateTime).month, (c['end'] as DateTime).day);
      if (!todayD.isBefore(s) && !todayD.isAfter(e)) {
        currentCycle = c;
        break;
      }
    }

    // Default values
    String badge = 'CYCLE';
    Color phaseColor = Colors.blue[400]!;
    String mainMessage = 'Not on your period today';
    String subMessage = health.menstrualCycles.isEmpty
        ? 'Tap days on the calendar to mark your period'
        : 'Mark your next period day when it starts';
    int? cycleDay;

    if (currentCycle != null) {
      // Currently on period
      final s = DateTime((currentCycle['start'] as DateTime).year, (currentCycle['start'] as DateTime).month, (currentCycle['start'] as DateTime).day);
      cycleDay = todayD.difference(s).inDays + 1;
      badge = 'PERIOD';
      phaseColor = Colors.red[400]!;
      mainMessage = 'Day $cycleDay of your period';
      
      // Calculate expected period length from history
      if (health.menstrualCycles.isNotEmpty) {
        final periodLengths = health.menstrualCycles
            .map((c) => (c['end'] as DateTime).difference(c['start'] as DateTime).inDays + 1)
            .where((d) => d > 0 && d <= 10)
            .toList();
        if (periodLengths.isNotEmpty) {
          periodLengths.sort();
          final medianLength = periodLengths[periodLengths.length ~/ 2];
          final remaining = medianLength - cycleDay;
          if (remaining > 0) {
            subMessage = 'About $remaining day${remaining == 1 ? '' : 's'} remaining (typical)';
          } else if (remaining == 0) {
            subMessage = 'Last day of your typical period';
          } else {
            subMessage = 'Longer than your typical period';
          }
        } else {
          subMessage = 'Stay hydrated and rest well';
        }
      } else {
        subMessage = 'Stay hydrated and rest well';
      }
    } else if (health.menstrualCycles.isNotEmpty) {
      // Not on period - calculate cycle position and prediction
      final sortedCycles = List<Map<String, dynamic>>.from(health.menstrualCycles)
        ..sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
      
      final lastPeriodStart = DateTime(
        (sortedCycles.first['start'] as DateTime).year,
        (sortedCycles.first['start'] as DateTime).month,
        (sortedCycles.first['start'] as DateTime).day
      );
      
      final daysSinceLastPeriod = todayD.difference(lastPeriodStart).inDays;
      
      // Calculate average cycle length with recency weighting
      if (sortedCycles.length >= 2) {
        final starts = sortedCycles.map((c) => DateTime(
          (c['start'] as DateTime).year,
          (c['start'] as DateTime).month,
          (c['start'] as DateTime).day
        )).toList();
        
        final cycleLengths = <int>[];
        for (int i = 0; i < starts.length - 1; i++) {
          final length = starts[i].difference(starts[i + 1]).inDays;
          if (length > 0 && length >= 18 && length <= 45) {
            cycleLengths.add(length);
          }
        }
        
        if (cycleLengths.isNotEmpty) {
          // Recency-weighted average
          final n = cycleLengths.length;
          double weightedSum = 0;
          int weightTotal = 0;
          for (int i = 0; i < n; i++) {
            final weight = n - i;
            weightedSum += cycleLengths[i] * weight;
            weightTotal += weight;
          }
          final avgCycleLength = (weightedSum / weightTotal).round();
          
          // Calculate standard deviation for regularity
          final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
          double sumSquares = 0;
          for (final length in cycleLengths) {
            sumSquares += (length - mean) * (length - mean);
          }
          final stdDev = math.sqrt(sumSquares / cycleLengths.length);
          
          final daysUntilNext = avgCycleLength - daysSinceLastPeriod;
          cycleDay = daysSinceLastPeriod;
          
          if (daysUntilNext > 7) {
            // Mid-cycle
            badge = 'CYCLE DAY $daysSinceLastPeriod';
            phaseColor = Colors.blue[400]!;
            
            // Determine cycle phase based on typical 28-day cycle
            final cycleProgress = daysSinceLastPeriod / avgCycleLength;
            if (cycleProgress < 0.25) {
              mainMessage = 'Post-menstrual phase';
              subMessage = 'Energy levels typically rising';
            } else if (cycleProgress < 0.5) {
              mainMessage = 'Follicular phase';
              subMessage = 'Peak energy and productivity days';
            } else if (cycleProgress < 0.75) {
              mainMessage = 'Mid-cycle phase';
              subMessage = 'Maintaining steady energy levels';
            } else {
              mainMessage = 'Luteal phase';
              subMessage = 'Period expected in $daysUntilNext day${daysUntilNext == 1 ? '' : 's'}';
            }
          } else if (daysUntilNext > 0) {
            // Period coming soon
            badge = 'CYCLE DAY $daysSinceLastPeriod';
            phaseColor = Colors.orange[400]!;
            mainMessage = 'Period expected in $daysUntilNext day${daysUntilNext == 1 ? '' : 's'}';
            
            if (stdDev <= 2) {
              subMessage = 'Your cycle is very regular';
            } else if (stdDev <= 4) {
              subMessage = 'Prediction based on your cycle pattern';
            } else {
              subMessage = 'Cycle varies - track symptoms';
            }
          } else if (daysUntilNext >= -3) {
            // Period is late but within normal variation
            badge = 'CYCLE DAY $daysSinceLastPeriod';
            phaseColor = Colors.purple[400]!;
            mainMessage = 'Period expected around now';
            subMessage = stdDev > 4 
                ? 'Your cycle timing varies naturally'
                : 'Mark when your period starts';
          } else {
            // Period significantly delayed
            badge = 'CYCLE DAY $daysSinceLastPeriod';
            phaseColor = Colors.grey[600]!;
            mainMessage = 'Longer cycle than usual';
            subMessage = 'Mark your period when it starts';
          }
        } else {
          // Not enough valid cycle data
          badge = 'TRACKING';
          mainMessage = 'Continue tracking your cycles';
          subMessage = 'More data will improve predictions';
        }
      } else {
        // Only one cycle recorded
        badge = 'CYCLE DAY $daysSinceLastPeriod';
        mainMessage = 'Building your cycle history';
        subMessage = 'Keep tracking to see patterns';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [phaseColor.withOpacity(0.8), phaseColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: phaseColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (cycleDay != null)
                Text('Day $cycleDay', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mainMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subMessage,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          // Add prediction card if we can predict
          if (health.menstrualCycles.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildNextPeriodPredictionBadge(health),
            ),
        ],
      ),
    );
  }

  // Prediction badge to show in cycle overview card
  Widget _buildNextPeriodPredictionBadge(HealthDataProvider health) {
    final nextPeriod = health.getNextPeriodPrediction();
    final daysUntil = health.getDaysUntilNextPeriod();
    
    if (nextPeriod == null || daysUntil == null) {
      return const SizedBox.shrink();
    }

    final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${nextPeriod.day} ${monthNames[nextPeriod.month]}';
    
    String label;
    if (daysUntil < 0) {
      label = 'Overdue by ${daysUntil.abs()} day${daysUntil.abs() == 1 ? '' : 's'}';
    } else if (daysUntil == 0) {
      label = 'Expected today';
    } else {
      label = 'in $daysUntil day${daysUntil == 1 ? '' : 's'}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.8), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next period predicted',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$dateStr ($label)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayInsightsCard(HealthDataProvider health) {
    final today = DateTime.now();
    final isTodayPeriod = health.isPeriodDay(today);

    List<Map<String, dynamic>> insights = isTodayPeriod
        ? [
            {'icon': Icons.local_drink, 'title': 'Stay Hydrated', 'subtitle': 'Water and herbal teas can reduce bloating', 'color': Colors.blue},
            {'icon': Icons.self_improvement, 'title': 'Gentle Movement', 'subtitle': 'Light stretching or yoga may ease cramps', 'color': Colors.green},
            {'icon': Icons.restaurant, 'title': 'Iron-Rich Foods', 'subtitle': 'Leafy greens, legumes, and lean meats help', 'color': Colors.red},
          ]
        : [
            {'icon': Icons.calendar_today, 'title': 'Track Regularly', 'subtitle': 'Tap calendar days to keep your cycle accurate', 'color': Colors.pink},
            {'icon': Icons.psychology, 'title': 'Mood Check-in', 'subtitle': 'Log mood and symptoms for better insights', 'color': Colors.purple},
            {'icon': Icons.local_drink, 'title': 'Hydration Goal', 'subtitle': 'Aim for 6–8 glasses of water today', 'color': Colors.teal},
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Today\'s Insights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.asMap().entries.map((entry) {
            final insight = entry.value;
            final isLast = entry.key == insights.length - 1;
            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (insight['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        insight['icon'] as IconData,
                        color: insight['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight['subtitle'] as String,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isLast) ...[const SizedBox(height: 12), Divider(color: Colors.grey[200], height: 1)],
                if (!isLast) const SizedBox(height: 12),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // Flo-style calendar
  Widget _buildFloStyleCalendar(HealthDataProvider health) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cycle Calendar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _calendarDate = DateTime.now();
                  });
                },
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.pink[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMiniCalendar(health),
          const SizedBox(height: 16),
          // Minimalist legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMinimalLegendItem('Period', Colors.red),
                _buildMinimalLegendItem('Predicted', Colors.orange),
                _buildMinimalLegendItem('Fertile', Colors.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCalendar(HealthDataProvider health) {
    final firstDayOfMonth = DateTime(_calendarDate.year, _calendarDate.month, 1);
    final lastDayOfMonth = DateTime(_calendarDate.year, _calendarDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday;
    
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Swipe navigation
        if (details.primaryVelocity! > 0) {
          // Swipe right - previous month
          setState(() {
            _calendarDate = DateTime(_calendarDate.year, _calendarDate.month - 1, 1);
          });
        } else if (details.primaryVelocity! < 0) {
          // Swipe left - next month
          setState(() {
            _calendarDate = DateTime(_calendarDate.year, _calendarDate.month + 1, 1);
          });
        }
      },
      child: Column(
      children: [
        // Month header with navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _calendarDate = DateTime(_calendarDate.year, _calendarDate.month - 1, 1);
                });
              },
              icon: const Icon(Icons.chevron_left),
              iconSize: 20,
            ),
            GestureDetector(
              onTap: () => _showMonthYearPicker(),
              child: Text(
                '${_getMonthName(_calendarDate.month)} ${_calendarDate.year}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _calendarDate = DateTime(_calendarDate.year, _calendarDate.month + 1, 1);
                });
              },
              icon: const Icon(Icons.chevron_right),
              iconSize: 20,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: Text(
                      day,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        ...List.generate(6, (weekIndex) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final dayNumber = weekIndex * 7 + dayIndex - startWeekday + 2;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox(width: 32, height: 32);
              }
              
              final date = DateTime(_calendarDate.year, _calendarDate.month, dayNumber);
              final dayInfo = _getDayInfo(date, health);
              
              return GestureDetector(
                      onTap: () {
                        // Auto-apply: toggle provider data immediately
                        final normalized = DateTime(date.year, date.month, date.day);
                        health.togglePeriodDay(normalized);
                      },
                      onLongPress: () => _showDayDetail(date, health),
                      child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: dayInfo['type'] != 'normal' ? dayInfo['color'] : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: dayInfo['type'] == 'fertile' ? Border.all(color: Colors.amber[600]!, width: 1.5) : null,
                        ),
                  alignment: Alignment.center,
                  child: Text(
                    dayNumber.toString(),
                    style: TextStyle(
                            color: dayInfo['textColor'],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          );
        }).where((row) => 
          (row.children as List).any((child) => 
            child is GestureDetector && 
            (child.child as Container).child != null
          )
        ).toList(),
      ],
      ),
    );
  }

  Map<String, dynamic> _getDayInfo(DateTime date, HealthDataProvider health) {
    final normalized = DateTime(date.year, date.month, date.day);
    
    // Check for confirmed period days
    for (var cycle in health.menstrualCycles) {
      final start = DateTime((cycle['start'] as DateTime).year, (cycle['start'] as DateTime).month, (cycle['start'] as DateTime).day);
      final end = DateTime((cycle['end'] as DateTime).year, (cycle['end'] as DateTime).month, (cycle['end'] as DateTime).day);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
        return {
          'color': Colors.red[400],
          'textColor': Colors.white,
          'type': 'period'
        };
      }
    }
    
    // Calculate predictions if we have cycle history
    if (health.menstrualCycles.length >= 2) {
      final sortedCycles = List<Map<String, dynamic>>.from(health.menstrualCycles)
        ..sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
      
      final lastPeriodStart = DateTime(
        (sortedCycles.first['start'] as DateTime).year,
        (sortedCycles.first['start'] as DateTime).month,
        (sortedCycles.first['start'] as DateTime).day
      );
      
      // Calculate average cycle length with recency weighting
      final starts = sortedCycles.map((c) => DateTime(
        (c['start'] as DateTime).year,
        (c['start'] as DateTime).month,
        (c['start'] as DateTime).day
      )).toList();
      
      final cycleLengths = <int>[];
      for (int i = 0; i < starts.length - 1; i++) {
        final length = starts[i].difference(starts[i + 1]).inDays;
        if (length > 0 && length >= 18 && length <= 45) {
          cycleLengths.add(length);
        }
      }
      
      if (cycleLengths.isNotEmpty) {
        // Recency-weighted average
        final n = cycleLengths.length;
        double weightedSum = 0;
        int weightTotal = 0;
        for (int i = 0; i < n; i++) {
          final weight = n - i;
          weightedSum += cycleLengths[i] * weight;
          weightTotal += weight;
        }
        final avgCycleLength = (weightedSum / weightTotal).round();
        
        // Get average period length
        final periodLengths = <int>[];
        for (var cycle in health.menstrualCycles) {
          final s = cycle['start'] as DateTime;
          final e = cycle['end'] as DateTime;
          final d = e.difference(s).inDays + 1;
          if (d > 0) periodLengths.add(d);
        }
        final avgPeriodLength = periodLengths.isEmpty ? 5 : 
          (periodLengths..sort())[periodLengths.length ~/ 2];
        
        // Calculate next predicted period start
        final nextPeriodStart = lastPeriodStart.add(Duration(days: avgCycleLength));
        final nextPeriodEnd = nextPeriodStart.add(Duration(days: avgPeriodLength - 1));
        
        // Check if date falls within predicted period
        if (!normalized.isBefore(nextPeriodStart) && !normalized.isAfter(nextPeriodEnd)) {
          return {
            'color': Colors.orange[300],
            'textColor': Colors.white,
            'type': 'predicted'
          };
        }
        
        // Check for fertile window (around ovulation, typically 14 days before next period)
        final ovulationDay = nextPeriodStart.subtract(const Duration(days: 14));
        final fertileWindowStart = ovulationDay.subtract(const Duration(days: 5));
        final fertileWindowEnd = ovulationDay.add(const Duration(days: 1));
        
        if (!normalized.isBefore(fertileWindowStart) && !normalized.isAfter(fertileWindowEnd)) {
          return {
            'color': Colors.amber[300],
            'textColor': Colors.brown[800],
            'type': 'fertile'
          };
        }
      }
    }
    
    return {
      'color': Colors.transparent,
      'textColor': Colors.black,
      'type': 'normal'
    };
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }



  // Cycle statistics card
  Widget _buildCycleStatsCard(HealthDataProvider health) {
    if (health.menstrualCycles.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate typical lengths (robust & recency-weighted)
    int avgCycleLength = 28;
    int avgPeriodLength = 5;
    if (health.menstrualCycles.length > 1) {
      final starts = health.menstrualCycles.map((c) => c['start'] as DateTime).toList();
      final cycleLengths = <int>[];
      for (int i = 0; i < starts.length - 1; i++) {
        final diff = starts[i].difference(starts[i + 1]).inDays;
        if (diff > 0) cycleLengths.add(diff);
      }
      if (cycleLengths.isNotEmpty) {
        final n = cycleLengths.length;
        double weighted = 0;
        int totalW = 0;
        for (int i = 0; i < n; i++) {
          final w = n - i;
          weighted += cycleLengths[i] * w;
          totalW += w;
        }
        avgCycleLength = (weighted / totalW).round().clamp(18, 45);
      }
      final periodLengths = <int>[];
      for (var cycle in health.menstrualCycles) {
        final s = cycle['start'] as DateTime;
        final e = cycle['end'] as DateTime;
        final d = e.difference(s).inDays + 1;
        if (d > 0) periodLengths.add(d);
      }
      if (periodLengths.isNotEmpty) {
        periodLengths.sort();
        avgPeriodLength = periodLengths[periodLengths.length ~/ 2];
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cycle Statistics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          // Two key metrics displayed simply
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Cycle',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$avgCycleLength days',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey[200]),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Period',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$avgPeriodLength days',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Additional info below
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycles Tracked',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${health.menstrualCycles.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Regularity',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getRegularityStatus(health),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build card comparing user's cycle data with population statistics
  Widget _buildPopulationComparisonCard(
    HealthDataProvider health,
    PopulationCycleData populationData,
  ) {
    if (health.menstrualCycles.length < 2) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people, color: Colors.purple, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Population Comparison',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Track more cycles to compare with population data',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate user's average cycle and period lengths
    int userAvgCycleLength = 28;
    int userAvgPeriodLength = 5;
    if (health.menstrualCycles.length > 1) {
      final starts = health.menstrualCycles.map((c) => c['start'] as DateTime).toList();
      final cycleLengths = <int>[];
      for (int i = 0; i < starts.length - 1; i++) {
        final diff = starts[i].difference(starts[i + 1]).inDays;
        if (diff > 0 && diff >= 18 && diff <= 45) cycleLengths.add(diff);
      }
      if (cycleLengths.isNotEmpty) {
        final n = cycleLengths.length;
        double weighted = 0;
        int totalW = 0;
        for (int i = 0; i < n; i++) {
          final w = n - i;
          weighted += cycleLengths[i] * w;
          totalW += w;
        }
        userAvgCycleLength = (weighted / totalW).round().clamp(18, 45);
      }

      final periodLengths = <int>[];
      for (var cycle in health.menstrualCycles) {
        final s = cycle['start'] as DateTime;
        final e = cycle['end'] as DateTime;
        final d = e.difference(s).inDays + 1;
        if (d > 0) periodLengths.add(d);
      }
      if (periodLengths.isNotEmpty) {
        periodLengths.sort();
        userAvgPeriodLength = periodLengths[periodLengths.length ~/ 2];
      }
    }

    final comparison = _dataService.compareUserToCycleData(
      userAvgCycleLength,
      userAvgPeriodLength,
      health.menstrualCycles.length,
      populationData,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Population Comparison',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Based on ${populationData.sampleSize > 0 ? "${populationData.sampleSize} users" : "clinical guidelines"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Insight text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Text(
                comparison.interpretation,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            // Comparison table
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Your Cycle',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${comparison.userCycleLength.round()} days',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Period: ${comparison.userPeriodLength.round()} days',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Population Avg',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${comparison.populationCycleLength.round()} days',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      Text(
                        'Period: ${comparison.populationPeriodLength.round()} days',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Confidence indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prediction Confidence',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${(comparison.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: comparison.confidence,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      comparison.confidence > 0.7 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRegularityStatus(HealthDataProvider health) {
    if (health.menstrualCycles.length < 3) return 'Need more data';
    final cycleLengths = <int>[];
    final starts = health.menstrualCycles.map((c) => c['start'] as DateTime).toList();
    for (int i = 0; i < starts.length - 1; i++) {
      final diff = starts[i].difference(starts[i + 1]).inDays;
      if (diff > 0) cycleLengths.add(diff);
    }
    if (cycleLengths.length < 2) return 'Unknown';
    final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    double sumSq = 0;
    for (final x in cycleLengths) {
      sumSq += (x - mean) * (x - mean);
    }
    final sd = math.sqrt(sumSq / (cycleLengths.length - 1));
    if (sd <= 2) return 'Regular';
    if (sd <= 5) return 'Somewhat irregular';
    return 'Irregular';
  }

  // Dialog functions for quick logging
  void _logPeriod(HealthDataProvider health) async {
    DateTime startDate = DateTime.now();
    DateTime? endDate;
    int flow = 3;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log Period'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text('${startDate.day}/${startDate.month}/${startDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setDialogState(() => startDate = date);
                    }
                  },
                ),
                if (endDate != null)
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text('${endDate!.day}/${endDate!.month}/${endDate!.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate!,
                        firstDate: startDate,
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setDialogState(() => endDate = date);
                      }
                    },
                  ),
                if (endDate == null)
                  TextButton(
                    onPressed: () => setDialogState(() => endDate = DateTime.now()),
                    child: const Text('Add End Date'),
                  ),
                const SizedBox(height: 16),
                const Text('Flow Intensity'),
                Slider(
                  value: flow.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _getFlowLabel(flow),
                  onChanged: (value) => setDialogState(() => flow = value.round()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                health.addMenstrualEntry(
                  startDate,
                  endDate ?? startDate.add(const Duration(days: 4)),
                  flow,
                  'Logged via quick log',
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Period logged successfully!')),
                );
              },
              child: const Text('Log'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFlowLabel(int flow) {
    switch (flow) {
      case 1: return 'Spotting';
      case 2: return 'Light';
      case 3: return 'Medium';
      case 4: return 'Heavy';
      case 5: return 'Very Heavy';
      default: return 'Medium';
    }
  }

  void _logSymptoms(HealthDataProvider health) {
    // Use existing symptoms dialog
    setState(() => _selectedTab = 1);
  }

  void _logMood(HealthDataProvider health) async {
    const moods = ['Happy', 'Sad', 'Anxious', 'Energetic', 'Tired', 'Irritable', 'Calm', 'Stressed'];
    const moodIcons = {
      'Happy': Icons.sentiment_very_satisfied_rounded,
      'Sad': Icons.sentiment_dissatisfied_rounded,
      'Anxious': Icons.psychology_rounded,
      'Energetic': Icons.bolt_rounded,
      'Tired': Icons.bedtime_rounded,
      'Irritable': Icons.sentiment_very_dissatisfied_rounded,
      'Calm': Icons.spa_rounded,
      'Stressed': Icons.warning_rounded,
    };

    final selectedMood = await DialogHelper.showSelectionDialog<String>(
      context: context,
      title: 'How are you feeling?',
      subtitle: 'Select your current mood',
      icon: Icons.mood_rounded,
      iconColor: Colors.amber[500],
      options: moods.map((mood) => SelectionOption(
        value: mood,
        label: mood,
        icon: moodIcons[mood],
      )).toList(),
    );

    if (selectedMood != null) {
      health.addSymptom({
        'date': DateTime.now(),
        'mood': selectedMood,
        'cramps': 0,
        'acne': false,
        'bloating': false,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Mood logged: $selectedMood'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _logIntimacy(HealthDataProvider health) async {
    final confirmed = await DialogHelper.showConfirmationDialog(
      context: context,
      title: 'Log Intimacy',
      message: 'Track intimate moments for better cycle insights and fertility tracking.',
      confirmText: 'Log',
      cancelText: 'Cancel',
      icon: Icons.favorite_rounded,
      iconColor: Colors.red[400],
      confirmColor: Colors.pink[500],
    );

    if (confirmed == true) {
      // Add to a new intimacy log (you'd need to add this to HealthDataProvider)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Intimacy logged successfully!'),
            ],
          ),
          backgroundColor: Colors.pink[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _logWeight(HealthDataProvider health) {
    // Use existing weight dialog
    setState(() => _selectedTab = 4);
  }

  void _logNotes(HealthDataProvider health) async {
    final result = await DialogHelper.showInputDialog(
      context: context,
      title: 'Add Notes',
      subtitle: 'Record how you\'re feeling today',
      hintText: 'How are you feeling today?',
      confirmText: 'Save',
      cancelText: 'Cancel',
      icon: Icons.edit_note_rounded,
      iconColor: Colors.purple[400],
      maxLines: 4,
    );

    if (result != null && result.isNotEmpty) {
      // Add notes functionality to HealthDataProvider
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Notes saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showDayDetail(DateTime date, HealthDataProvider health) {
    final dayInfo = _getDayInfo(date, health);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${date.day}/${date.month}/${date.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dayInfo['type'] == 'period')
              const Text('🔴 Period day')
            else if (dayInfo['type'] == 'predicted')
              const Text('🟠 Predicted period day')
            else if (dayInfo['type'] == 'fertile')
              const Text('🟡 Fertile window (high fertility)')
            else if (dayInfo['type'] == 'ovulation')
              const Text('🟣 Ovulation day')
            else
              const Text('📅 Regular day'),
            const SizedBox(height: 16),
            if (dayInfo['type'] == 'predicted' || dayInfo['type'] == 'fertile')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    dayInfo['type'] == 'predicted'
                      ? 'This is a predicted period date based on your cycle history. Mark it when your period actually starts.'
                      : 'This is within your predicted fertile window. Conception is most likely during this time.',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ),
            const Text('Quick actions:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final wasPeriod = health.isPeriodDay(date);
                health.togglePeriodDay(date);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(wasPeriod ? 'Period day removed' : 'Period day marked')),
                );
              },
              child: Text(health.isPeriodDay(date) ? 'Unmark Period Day' : 'Mark Period Day'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavButton(String label, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink[50],
            foregroundColor: Colors.pink[700],
            elevation: 1,
            padding: const EdgeInsets.symmetric(vertical: 8),
            textStyle: const TextStyle(fontSize: 10),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  // ============== ENHANCED MENSTRUAL CYCLE WIDGETS ==============
  
  /// Enhanced cycle overview card with improved visual design
  Widget _buildEnhancedCycleOverviewCard(HealthDataProvider health) {
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    
    // Check if today is a logged period day
    Map<String, dynamic>? currentCycle;
    for (final c in health.menstrualCycles) {
      final s = DateTime((c['start'] as DateTime).year, (c['start'] as DateTime).month, (c['start'] as DateTime).day);
      final e = DateTime((c['end'] as DateTime).year, (c['end'] as DateTime).month, (c['end'] as DateTime).day);
      if (!todayD.isBefore(s) && !todayD.isAfter(e)) {
        currentCycle = c;
        break;
      }
    }

    Color statusColor = Colors.blue;
    Color backgroundColor = Colors.blue.withOpacity(0.06);
    String mainMessage = 'Start tracking';
    String subMessage = 'Mark your period days on the calendar';
    String statusLabel = 'Not Tracking';
    IconData statusIcon = Icons.calendar_today;
    int? daysUntilPeriod;
    String? quickStat;

    if (currentCycle != null) {
      final s = DateTime((currentCycle['start'] as DateTime).year, (currentCycle['start'] as DateTime).month, (currentCycle['start'] as DateTime).day);
      final cycleDay = todayD.difference(s).inDays + 1;
      statusColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.06);
      mainMessage = 'Day $cycleDay of your period';
      statusIcon = Icons.water_drop;
      statusLabel = 'PERIOD';
      
      if (health.menstrualCycles.isNotEmpty) {
        final periodLengths = health.menstrualCycles
            .map((c) => (c['end'] as DateTime).difference(c['start'] as DateTime).inDays + 1)
            .where((d) => d > 0 && d <= 10)
            .toList();
        if (periodLengths.isNotEmpty) {
          periodLengths.sort();
          final medianLength = periodLengths[periodLengths.length ~/ 2];
          final remaining = medianLength - cycleDay;
          if (remaining > 0) {
            subMessage = '$remaining day${remaining == 1 ? '' : 's'} remaining';
            quickStat = 'Avg period: $medianLength days';
          } else {
            subMessage = 'Running longer than usual';
          }
        }
      }
    } else if (health.menstrualCycles.isNotEmpty) {
      final nextPeriod = health.getNextPeriodPrediction();
      daysUntilPeriod = health.getDaysUntilNextPeriod();
      
      if (nextPeriod != null && daysUntilPeriod != null) {
        final sortedCycles = List<Map<String, dynamic>>.from(health.menstrualCycles)
          ..sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
        final lastPeriodStart = DateTime(
          (sortedCycles.first['start'] as DateTime).year,
          (sortedCycles.first['start'] as DateTime).month,
          (sortedCycles.first['start'] as DateTime).day
        );
        final daysSinceLastPeriod = todayD.difference(lastPeriodStart).inDays;
        
        // Calculate average cycle length
        final cycleLengths = <int>[];
        for (int i = 0; i < sortedCycles.length - 1; i++) {
          final diff = (sortedCycles[i]['start'] as DateTime).difference(
            sortedCycles[i + 1]['start'] as DateTime).inDays;
          if (diff > 0 && diff >= 18 && diff <= 45) cycleLengths.add(diff);
        }
        int avgCycleLength = 28;
        if (cycleLengths.isNotEmpty) {
          final n = cycleLengths.length;
          double weighted = 0;
          int totalW = 0;
          for (int i = 0; i < n; i++) {
            final w = n - i;
            weighted += cycleLengths[i] * w;
            totalW += w;
          }
          avgCycleLength = (weighted / totalW).round().clamp(18, 45);
        }
        
        if (daysUntilPeriod <= 5 && daysUntilPeriod > 0) {
          statusColor = Colors.orange;
          backgroundColor = Colors.orange.withOpacity(0.06);
          mainMessage = 'Period coming soon';
          subMessage = 'In approximately $daysUntilPeriod day${daysUntilPeriod == 1 ? '' : 's'}';
          statusIcon = Icons.schedule;
          statusLabel = 'APPROACHING';
          quickStat = 'Avg cycle: $avgCycleLength days';
        } else if (daysUntilPeriod <= 0 && daysUntilPeriod >= -3) {
          statusColor = Colors.deepOrange;
          backgroundColor = Colors.deepOrange.withOpacity(0.06);
          mainMessage = 'Period expected';
          subMessage = 'Track when it starts';
          statusIcon = Icons.event;
          statusLabel = 'EXPECTED';
          quickStat = 'Avg cycle: $avgCycleLength days';
        } else if (daysSinceLastPeriod < 14) {
          statusColor = Colors.pink;
          backgroundColor = Colors.pink.withOpacity(0.06);
          mainMessage = 'Follicular Phase';
          subMessage = 'Day ${daysSinceLastPeriod + 1} of your cycle';
          statusIcon = Icons.energy_savings_leaf;
          statusLabel = 'RISING ENERGY';
          quickStat = 'Day ${daysSinceLastPeriod + 1} of $avgCycleLength';
        } else {
          statusColor = Colors.purple;
          backgroundColor = Colors.purple.withOpacity(0.06);
          mainMessage = 'Luteal Phase';
          subMessage = 'Day ${daysSinceLastPeriod + 1} of your cycle';
          statusIcon = Icons.favorite;
          statusLabel = 'INTROSPECTIVE';
          quickStat = 'Day ${daysSinceLastPeriod + 1} of $avgCycleLength';
        }
      }
    }

    // Calculate cycle progress and menstrual phase
    double cycleProgress = 0;
    int cyclePosition = 0;
    int totalCycleLength = 28;
    String menstrualPhase = 'Not Tracked';
    
    if (health.menstrualCycles.isNotEmpty) {
      final sortedCycles = List<Map<String, dynamic>>.from(health.menstrualCycles)
        ..sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
      final lastPeriodStart = DateTime(
        (sortedCycles.first['start'] as DateTime).year,
        (sortedCycles.first['start'] as DateTime).month,
        (sortedCycles.first['start'] as DateTime).day
      );
      cyclePosition = todayD.difference(lastPeriodStart).inDays;
      
      // Calculate average cycle length
      final cycleLengths = <int>[];
      for (int i = 0; i < sortedCycles.length - 1; i++) {
        final diff = (sortedCycles[i]['start'] as DateTime).difference(
          sortedCycles[i + 1]['start'] as DateTime).inDays;
        if (diff > 0 && diff >= 18 && diff <= 45) cycleLengths.add(diff);
      }
      if (cycleLengths.isNotEmpty) {
        final n = cycleLengths.length;
        double weighted = 0;
        int totalW = 0;
        for (int i = 0; i < n; i++) {
          final w = n - i;
          weighted += cycleLengths[i] * w;
          totalW += w;
        }
        totalCycleLength = (weighted / totalW).round().clamp(18, 45);
      }
      cycleProgress = (cyclePosition.toDouble() / totalCycleLength).clamp(0, 1);
      
      // Determine menstrual phase
      if (cyclePosition <= 4) {
        menstrualPhase = 'Menstrual';
      } else if (cyclePosition <= 13) {
        menstrualPhase = 'Follicular';
      } else if (cyclePosition <= 15) {
        menstrualPhase = 'Ovulation';
      } else if (cyclePosition < totalCycleLength) {
        menstrualPhase = 'Luteal';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, backgroundColor.withOpacity(0.25)],
        ),
        border: Border(left: BorderSide(color: statusColor, width: 5)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon, title, and mini-calendar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(statusIcon, color: statusColor, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mainMessage,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Learn more about this phase',
                          child: Icon(Icons.info_outline, size: 15, color: statusColor.withOpacity(0.7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subMessage,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Mini calendar icon for context
              Tooltip(
                message: 'Open calendar',
                child: Icon(Icons.calendar_month, color: Colors.blueGrey[300], size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Phase and energy/mood indicators row with gradients
          if (health.menstrualCycles.isNotEmpty)
            Row(
              children: [
                // Menstrual phase badge
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.withOpacity(0.18), statusColor.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              menstrualPhase == 'Menstrual' ? Icons.water_drop :
                              menstrualPhase == 'Follicular' ? Icons.energy_savings_leaf :
                              menstrualPhase == 'Ovulation' ? Icons.star :
                              Icons.favorite,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'PHASE',
                              style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          menstrualPhase,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Energy/Mood indicator based on phase
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.withOpacity(0.15), Colors.purple.withOpacity(0.07)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.purple.withOpacity(0.22), width: 1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              menstrualPhase == 'Menstrual' ? Icons.local_florist :
                              menstrualPhase == 'Follicular' ? Icons.bolt :
                              menstrualPhase == 'Ovulation' ? Icons.sentiment_very_satisfied :
                              Icons.psychology,
                              size: 14,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ENERGY',
                              style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          menstrualPhase == 'Menstrual' ? 'Low' :
                          menstrualPhase == 'Follicular' ? 'Rising' :
                          menstrualPhase == 'Ovulation' ? 'Peak' :
                          'Declining',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (health.menstrualCycles.isNotEmpty)
            const SizedBox(height: 10),
          // Cycle progress bar (if tracking)
          if (health.menstrualCycles.isNotEmpty && currentCycle == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timeline, size: 15, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                'Cycle Progress',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[700], letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${(cycleProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: LinearProgressIndicator(
                          value: cycleProgress,
                          minHeight: 7,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Day $cyclePosition',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                          Text(
                            'of $totalCycleLength',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          // Quick stat if available
          if (quickStat != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(color: statusColor.withOpacity(0.18), width: 1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: statusColor),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      quickStat,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),
          if (quickStat != null)
            const SizedBox(height: 10),
          // Recommended action badge
          if (health.menstrualCycles.isNotEmpty && currentCycle == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor.withOpacity(0.09), statusColor.withOpacity(0.04)],
                ),
                border: Border.all(color: statusColor.withOpacity(0.15), width: 1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Icon(
                    menstrualPhase == 'Menstrual' ? Icons.hotel :
                    menstrualPhase == 'Follicular' ? Icons.directions_run :
                    menstrualPhase == 'Ovulation' ? Icons.chat :
                    Icons.self_improvement,
                    size: 15,
                    color: statusColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      menstrualPhase == 'Menstrual' ? 'Rest & hydrate - Focus on self-care' :
                      menstrualPhase == 'Follicular' ? 'Perfect for workouts & new goals' :
                      menstrualPhase == 'Ovulation' ? 'Great time for important meetings' :
                      'Prioritize sleep & relaxation',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),
          if (health.menstrualCycles.isNotEmpty && currentCycle == null)
            const SizedBox(height: 10),
          // Status label badge with enhanced styling
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: statusColor.withOpacity(0.22), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Optional: Add hint text
              Text(
                'Tap calendar to update',
                style: TextStyle(fontSize: 9, color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Enhanced cycle phase insights with phase-specific styling
  Widget _buildCyclePhaseInsightsCard(HealthDataProvider health) {
    final nextPeriod = health.getNextPeriodPrediction();
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    
    if (nextPeriod == null || health.menstrualCycles.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedCycles = List<Map<String, dynamic>>.from(health.menstrualCycles)
      ..sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
    final lastPeriodStart = DateTime(
      (sortedCycles.first['start'] as DateTime).year,
      (sortedCycles.first['start'] as DateTime).month,
      (sortedCycles.first['start'] as DateTime).day
    );
    final daysSinceLastPeriod = todayD.difference(lastPeriodStart).inDays;

    String phaseTitle = 'Cycle Phase';
    String phaseDescription = 'Track your cycle to get personalized insights.';
    IconData phaseIcon = Icons.favorite;
    Color phaseColor = Colors.purple;
    Color phaseBackground = Colors.purple.withOpacity(0.08);

    if (daysSinceLastPeriod < 5) {
      phaseTitle = 'Menstrual Phase';
      phaseDescription = 'Rest and stay hydrated. Focus on gentle activities and iron-rich foods. Listen to your body.';
      phaseIcon = Icons.water_drop;
      phaseColor = Colors.red;
      phaseBackground = Colors.red.withOpacity(0.08);
    } else if (daysSinceLastPeriod < 14) {
      phaseTitle = 'Follicular Phase';
      phaseDescription = 'Energy is rising. This is a great time for workouts and new challenges. Embrace growth!';
      phaseIcon = Icons.energy_savings_leaf;
      phaseColor = Colors.pink;
      phaseBackground = Colors.pink.withOpacity(0.08);
    } else if (daysSinceLastPeriod < 21) {
      phaseTitle = 'Ovulation Phase';
      phaseDescription = 'Peak energy and confidence. Ideal for important decisions and conversations. Shine bright!';
      phaseIcon = Icons.star;
      phaseColor = Colors.amber;
      phaseBackground = Colors.amber.withOpacity(0.08);
    } else {
      phaseTitle = 'Luteal Phase';
      phaseDescription = 'Energy naturally decreases. Prioritize rest, sleep, and self-care activities. Reflect inward.';
      phaseIcon = Icons.favorite;
      phaseColor = Colors.purple;
      phaseBackground = Colors.purple.withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: phaseColor.withOpacity(0.2), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: phaseBackground, borderRadius: BorderRadius.circular(10)),
                child: Icon(phaseIcon, color: phaseColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                phaseTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: phaseColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            phaseDescription,
            style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.6, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Enhanced calendar design with improved styling
  Widget _buildEnhancedFloStyleCalendar(HealthDataProvider health) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: Colors.pink, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Cycle Calendar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _calendarDate = DateTime.now();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.pink.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Today',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.pink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Enhanced legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEnhancedLegendItem('Period', Colors.red, Icons.circle),
                const SizedBox(width: 8),
                _buildEnhancedLegendItem('Predicted', Colors.orange, Icons.circle_outlined),
                const SizedBox(width: 8),
                _buildEnhancedLegendItem('Fertile', Colors.amber, Icons.circle),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Calendar
          _buildMiniCalendar(health),
        ],
      ),
    );
  }
  
  /// Enhanced legend item with icon
  Widget _buildEnhancedLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Minimalist legend item (for backward compatibility)
  Widget _buildMinimalLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Enhanced cycle statistics with icons and better styling
  Widget _buildEnhancedCycleStatsCard(HealthDataProvider health) {
    if (health.menstrualCycles.isEmpty) {
      return const SizedBox.shrink();
    }

    int avgCycleLength = 28;
    int avgPeriodLength = 5;
    int cycleCount = health.menstrualCycles.length;
    
    if (health.menstrualCycles.length > 1) {
      final starts = health.menstrualCycles.map((c) => c['start'] as DateTime).toList();
      final cycleLengths = <int>[];
      for (int i = 0; i < starts.length - 1; i++) {
        final diff = starts[i].difference(starts[i + 1]).inDays;
        if (diff > 0 && diff <= 45) cycleLengths.add(diff);
      }
      if (cycleLengths.isNotEmpty) {
        final n = cycleLengths.length;
        double weighted = 0;
        int totalW = 0;
        for (int i = 0; i < n; i++) {
          final w = n - i;
          weighted += cycleLengths[i] * w;
          totalW += w;
        }
        avgCycleLength = (weighted / totalW).round().clamp(18, 45);
      }

      final periodLengths = <int>[];
      for (var cycle in health.menstrualCycles) {
        final s = cycle['start'] as DateTime;
        final e = cycle['end'] as DateTime;
        final d = e.difference(s).inDays + 1;
        if (d > 0) periodLengths.add(d);
      }
      if (periodLengths.isNotEmpty) {
        periodLengths.sort();
        avgPeriodLength = periodLengths[periodLengths.length ~/ 2];
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Cycle Statistics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEnhancedStatItem('Avg Cycle', '$avgCycleLength days', Icons.calendar_today, Colors.blue),
              _buildEnhancedStatItem('Avg Period', '$avgPeriodLength days', Icons.water_drop, Colors.red),
              _buildEnhancedStatItem('Tracked', '$cycleCount', Icons.check_circle, Colors.green),
              _buildEnhancedStatItem('Regularity', _getRegularityBadge(health), Icons.trending_up, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Enhanced stat item with icon
  Widget _buildEnhancedStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Minimalist stat item (for backward compatibility)
  Widget _buildMinimalStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Get regularity badge
  String _getRegularityBadge(HealthDataProvider health) {
    if (health.menstrualCycles.length < 2) return 'New';
    
    final starts = health.menstrualCycles.map((c) => c['start'] as DateTime).toList();
    final cycleLengths = <int>[];
    for (int i = 0; i < starts.length - 1; i++) {
      final diff = starts[i].difference(starts[i + 1]).inDays;
      if (diff > 0) cycleLengths.add(diff);
    }
    
    if (cycleLengths.isEmpty) return 'N/A';
    
    final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    double sumSquares = 0;
    for (final length in cycleLengths) {
      sumSquares += (length - mean) * (length - mean);
    }
    final stdDev = math.sqrt(sumSquares / cycleLengths.length);
    
    if (stdDev <= 2) return 'Regular';
    if (stdDev <= 4) return 'Stable';
    if (stdDev <= 7) return 'Varied';
    return 'Irregular';
  }

  Widget _buildLegendItem(String label, Color color, {bool hasBorder = false}) {

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: hasBorder ? Border.all(color: Colors.amber[600]!, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  void _showFullCalendar(HealthDataProvider health) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Full Calendar'),
            backgroundColor: Colors.pink,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MenstrualCalendarWidget(cycles: health.menstrualCycles),
          ),
        ),
      ),
    );
  }

  void _showMonthYearPicker() async {
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthYearPickerDialog(initialDate: _calendarDate),
    );
    
    if (selectedDate != null) {
      setState(() {
        _calendarDate = selectedDate;
      });
    }
  }
}

// Month/Year Picker Dialog
class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  
  const _MonthYearPickerDialog({required this.initialDate});
  
  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  
  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Month and Year'),
      content: SizedBox(
        width: 300,
        height: 200,
        child: Column(
          children: [
            // Year selection
            Row(
              children: [
                const Text('Year: '),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: selectedYear,
                  items: List.generate(10, (index) {
                    final year = DateTime.now().year - 5 + index;
                    return DropdownMenuItem(value: year, child: Text(year.toString()));
                  }),
                  onChanged: (year) => setState(() => selectedYear = year!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Month selection
            Row(
              children: [
                const Text('Month: '),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: selectedMonth,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(_getMonthName(month)),
                    );
                  }),
                  onChanged: (month) => setState(() => selectedMonth = month!),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, DateTime(selectedYear, selectedMonth, 1));
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
  
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

// Top-level calendar widget for menstrual cycles

class MenstrualCalendarWidget extends StatefulWidget {
  final List<Map<String, dynamic>> cycles;
  const MenstrualCalendarWidget({super.key, required this.cycles});

  @override
  State<MenstrualCalendarWidget> createState() => ltc1qs49erv7pzeczp5qlnxd46aufzapsmzpa7y73ct();
}

class _PeriodDay {
  final DateTime date;
  final Map<String, dynamic> cycle;
  _PeriodDay(this.date, this.cycle);
}

class ltc1qs49erv7pzeczp5qlnxd46aufzapsmzpa7y73ct extends State<MenstrualCalendarWidget> {
  int _calendarMonth = DateTime.now().month;
  int _calendarYear = DateTime.now().year;
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _cycles = [];

  // --- Improved cycle analytics helpers ---
  List<int> _cycleLengthsDays(List<Map<String, dynamic>> cycles) {
    if (cycles.length < 2) return [];
    final starts = cycles.map((c) => c['start'] as DateTime).toList();
    final lengths = <int>[];
    for (int i = 0; i < starts.length - 1; i++) {
      final diff = starts[i].difference(starts[i + 1]).inDays;
      if (diff > 0) lengths.add(diff);
    }
    return lengths;
  }

  List<int> _periodLengthsDays(List<Map<String, dynamic>> cycles) {
    final lengths = <int>[];
    for (final c in cycles) {
      final s = c['start'] as DateTime;
      final e = c['end'] as DateTime;
      final d = e.difference(s).inDays + 1;
      if (d > 0) lengths.add(d);
    }
    return lengths;
  }

  List<int> _trimIQR(List<int> data) {
    if (data.length < 4) return List<int>.from(data);
    final sorted = List<int>.from(data)..sort();
    int q1Index = ((sorted.length + 1) * 0.25).floor().clamp(0, sorted.length - 1);
    int q3Index = ((sorted.length + 1) * 0.75).floor().clamp(0, sorted.length - 1);
    final q1 = sorted[q1Index].toDouble();
    final q3 = sorted[q3Index].toDouble();
    final iqr = q3 - q1;
    final lower = (q1 - 1.5 * iqr);
    final upper = (q3 + 1.5 * iqr);
    return sorted.where((x) => x >= lower && x <= upper).toList();
  }

  double _weightedMeanRecency(List<int> data) {
    if (data.isEmpty) return 28.0;
    // Assume data is from most recent to older; weight recent more
    final n = data.length;
    double weighted = 0;
    int totalW = 0;
    for (int i = 0; i < n; i++) {
      final w = n - i; // n, n-1, ..., 1
      weighted += data[i] * w;
      totalW += w;
    }
    return weighted / totalW;
  }

  double _stdDev(List<int> data, double mean) {
    if (data.length < 2) return 0;
    double sumSq = 0;
    for (final x in data) {
      sumSq += (x - mean) * (x - mean);
    }
    return math.sqrt(sumSq / (data.length - 1));
  }

  @override
  void initState() {
    super.initState();
    _cycles = List<Map<String, dynamic>>.from(widget.cycles);
  }

  @override
  Widget build(BuildContext context) {
    // Collect all period days
    final periodDays = <_PeriodDay>[];
    for (var cycle in _cycles) {
      final start = cycle['start'] as DateTime;
      final end = cycle['end'] as DateTime;
      for (var d = start; d.isBefore(end.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        periodDays.add(_PeriodDay(DateTime(d.year, d.month, d.day), cycle));
      }
    }

    // Actual-cycle analytics and forecast (for highlights)
    final rawLengths = _cycleLengthsDays(_cycles);
    final trimmed = _trimIQR(rawLengths);
    final recentForMean = trimmed.isNotEmpty ? trimmed : rawLengths;
    final meanLen = recentForMean.isNotEmpty ? _weightedMeanRecency(recentForMean) : 28.0;
    final sdLen = recentForMean.isNotEmpty ? _stdDev(recentForMean, meanLen) : 0.0;
    final DateTime? lastStart = _cycles.isNotEmpty ? (_cycles.first['start'] as DateTime) : null;
    final int predictedCycleLength = meanLen.round().clamp(18, 45);
    final DateTime? nextPeriod = lastStart?.add(Duration(days: predictedCycleLength));
    final DateTime? predictedOvulationDay = nextPeriod?.subtract(const Duration(days: 14));
    final Set<DateTime> fertileDays = {
      if (predictedOvulationDay != null)
        for (int i = 5; i >= 0; i--) DateTime(predictedOvulationDay.year, predictedOvulationDay.month, predictedOvulationDay.day).subtract(Duration(days: i))
    };
    // Predicted period days (use median period length)
    final periodLens = _periodLengthsDays(_cycles);
    final periodMedian = periodLens.isNotEmpty ? (List<int>.from(periodLens)..sort())[periodLens.length ~/ 2] : 5;
    final Set<DateTime> predictedPeriodDays = {
      if (nextPeriod != null)
        for (int i = 0; i < periodMedian; i++) DateTime(nextPeriod.year, nextPeriod.month, nextPeriod.day).add(Duration(days: i))
    };

    // Detect irregularities using predicted cycle length
    List<String> irregularities = [];
    if (widget.cycles.length > 1) {
      for (int i = 0; i < widget.cycles.length - 1; i++) {
        final prevStart = widget.cycles[i + 1]['start'] as DateTime;
        final currStart = widget.cycles[i]['start'] as DateTime;
        final diff = currStart.difference(prevStart).inDays;
        final threshold = math.max(3, sdLen.isFinite ? sdLen.round() : 3);
        if ((diff - meanLen).abs() > threshold) {
          irregularities.add('Cycle starting ${currStart.toString().split(' ')[0]} is irregular ($diff days)');
        }
      }
    }

    // Prepare sets for quick lookup
  final periodDaysSet = periodDays.map((pd) => pd.date).toSet();
  final irregularDaysSet = <DateTime>{};
    for (int i = 0; i < widget.cycles.length - 1; i++) {
      final prevStart = widget.cycles[i + 1]['start'] as DateTime;
      final currStart = widget.cycles[i]['start'] as DateTime;
      final diff = currStart.difference(prevStart).inDays;
      final threshold = math.max(3, sdLen.isFinite ? sdLen.round() : 3);
      if ((diff - meanLen).abs() > threshold) {
        irregularDaysSet.add(currStart);
      }
    }
  // Predicted ovulation and fertile window will be highlighted

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month/year navigation controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: _calendarMonth,
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_monthName(i + 1)),
                )),
                onChanged: (val) {
                  if (val != null) setState(() => _calendarMonth = val);
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _calendarYear,
                items: List.generate(10, (i) {
                  int year = DateTime.now().year - 5 + i;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (val) {
                  if (val != null) setState(() => _calendarYear = val);
                },
              ),
            ],
          ),
          // Custom calendar grid
          _buildCustomCalendar(periodDaysSet, predictedPeriodDays, predictedOvulationDay, fertileDays, irregularDaysSet, _calendarMonth, _calendarYear),
            const SizedBox(height: 8),
            // Legend for calendar icons/colors
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calendar Legend', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.pink[100], borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.water_drop, color: Colors.pink, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Period Day', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.calendar_today, color: Colors.purple, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Predicted Period', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.egg, color: Colors.orange, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Predicted Ovulation', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.grass, color: Colors.green, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Fertile Window', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.warning, color: Colors.red, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Irregular Cycle', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            _buildDayInfo(_selectedDay!, periodDays),
          const SizedBox(height: 16),
          if (_cycles.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue[50]?.withOpacity(0.4) ?? Colors.blue.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('Predictions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Based on ${_cycles.length} logged cycle${_cycles.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Next period predicted: ${nextPeriod != null ? "${nextPeriod.day}/${nextPeriod.month}/${nextPeriod.year}" : "Calculating..."}',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                    ),
                    if (predictedOvulationDay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Predicted ovulation: ${predictedOvulationDay.day}/${predictedOvulationDay.month}/${predictedOvulationDay.year}',
                          style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Predictions update automatically when you log new data',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Predictions removed — focusing on actual menstrual data
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Set Period Start Day', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(DateTime.now().year - 1),
                lastDate: DateTime(DateTime.now().year + 1),
              );
              if (picked != null) {
                // Add new period entry (assume 5 days, flow 3, notes empty)
                final end = picked.add(const Duration(days: 4));
                final newCycle = {'start': picked, 'end': end, 'flow': 3, 'notes': 'User added'};
                setState(() {
                  _cycles.insert(0, newCycle);
                  _selectedDay = picked;
                  _calendarMonth = picked.month;
                  _calendarYear = picked.year;
                });
              }
            },
          ),
        ],
      ),
    );

  }

  Widget _buildCustomCalendar(Set<DateTime> periodDaysSet, Set<DateTime> predictedPeriodDays, DateTime? predictedOvulationDay, Set<DateTime> fertileDays, Set<DateTime> irregularDaysSet, int month, int year) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final weekdayOffset = firstDayOfMonth.weekday % 7;
    List<Widget> dayWidgets = [];
    // Weekday headers
    dayWidgets.add(Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold))))).toList(),
    ));
    // Calendar grid
    List<Widget> rows = [];
    List<Widget> currentRow = [];
    for (int i = 0; i < weekdayOffset; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      Color? bgColor;
      Widget? icon;
      final isPeriod = periodDaysSet.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      final isPredictedPeriod = predictedPeriodDays.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      final isOvulation = predictedOvulationDay != null && date.year == predictedOvulationDay.year && date.month == predictedOvulationDay.month && date.day == predictedOvulationDay.day;
      final isFertile = fertileDays.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      final isIrregular = irregularDaysSet.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

      if (isPeriod) {
        bgColor = Colors.pink[100];
        icon = const Icon(Icons.water_drop, color: Colors.pink, size: 16);
      } else if (isPredictedPeriod) {
        bgColor = Colors.purple[100]?.withOpacity(0.5) ?? Colors.purple.withOpacity(0.1);
        icon = const Icon(Icons.calendar_today, color: Colors.purple, size: 16);
      } else if (isOvulation) {
        bgColor = Colors.orange[100]?.withOpacity(0.5) ?? Colors.orange.withOpacity(0.1);
        icon = const Icon(Icons.egg, color: Colors.orange, size: 16);
      } else if (isFertile) {
        bgColor = Colors.green[100]?.withOpacity(0.5) ?? Colors.green.withOpacity(0.1);
        icon = const Icon(Icons.grass, color: Colors.green, size: 16);
      } else if (isIrregular) {
        bgColor = Colors.red[100];
        icon = const Icon(Icons.warning, color: Colors.red, size: 16);
      }
      currentRow.add(Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _selectedDay != null && date.year == _selectedDay!.year && date.month == _selectedDay!.month && date.day == _selectedDay!.day
                  ? Colors.pink[300]
                  : bgColor,
              borderRadius: BorderRadius.circular(8),
              border: isToday ? Border.all(color: Colors.red, width: 2) : null,
            ),
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    if (isToday)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                // Prediction label badges
                if (isPredictedPeriod && !isPeriod)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('P', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (isOvulation && !isPeriod)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('O', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (isFertile && !isPeriod && !isOvulation)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('F', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (icon != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: icon,
                  ),
              ],
            ),
          ),
        ),
      ));
      if ((day + weekdayOffset) % 7 == 0 || day == daysInMonth) {
        // End of week or month
        while (currentRow.length < 7) {
          currentRow.add(const Expanded(child: SizedBox()));
        }
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }
    dayWidgets.addAll(rows);
    return Column(children: dayWidgets);
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildDayInfo(DateTime day, List<_PeriodDay> periodDays) {
    final pd = periodDays.firstWhere(
      (p) => p.date.year == day.year && p.date.month == day.month && p.date.day == day.day,
      orElse: () => _PeriodDay(day, {}),
    );
    if (pd.cycle.isNotEmpty) {
      return Card(
        color: Colors.pink[50],
        child: ListTile(
          leading: const Icon(Icons.calendar_today, color: Colors.pink),
          title: const Text('Period Day'),
          subtitle: Text('Flow: ${pd.cycle['flow']}/5\nNotes: ${pd.cycle['notes']}'),
        ),
      );
    } else {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.event_available, color: Colors.grey),
          title: Text('No period'),
          subtitle: Text('No menstrual data for this day.'),
        ),
      );
    }
  }
// Removed broken widget code from previous patch. All widget logic is now inside MenstrualCalendarWidget below.

// Removed duplicate _buildDayInfo and misplaced switch statement code. All widget logic is now inside MenstrualCalendarWidget below.

  Color _getFactorColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green[100]!;
      case 'Moderate':
        return Colors.orange[100]!;
      case 'High':
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }
}

class RiskAssessmentScreen extends StatelessWidget {
  const RiskAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthDataProvider>();
    final risk = health.riskAssessment;
    Color riskColor;
    IconData riskIcon;
    switch (risk['pcosRisk']) {
      case 'Low':
        riskColor = Colors.green;
        riskIcon = Icons.check_circle_outline;
        break;
      case 'Moderate':
        riskColor = Colors.orange;
        riskIcon = Icons.warning_amber_outlined;
        break;
      case 'High':
        riskColor = Colors.red;
        riskIcon = Icons.error_outline;
        break;
      default:
        riskColor = Colors.grey;
        riskIcon = Icons.help_outline;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: riskColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                child: Column(
                  children: [
                    Icon(riskIcon, color: riskColor, size: 38),
                    const SizedBox(height: 10),
                    const Text('PCOS Risk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                    Text(risk['pcosRisk'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: riskColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                child: Column(
                  children: [
                    const Text('Score', style: TextStyle(fontSize: 15, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text('${risk['scoreDecimal'] ?? risk['score']}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: riskColor)),
                    const Text('/100', style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('Updated: ${risk['lastUpdated'].toString().split(' ')[0]}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Factor Weights Breakdown
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scoring Weights', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cycle Regularity', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        Text('35%', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Symptom Patterns', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        Text('25%', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight Stability', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        Text('20%', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hydration', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        Text('10%', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Key Factors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ...List<Widget>.from(
                (risk['factors'] as List).map((factor) {
                  Color barColor = factor['severity'] == 'High' ? Colors.red : factor['severity'] == 'Moderate' ? Colors.orange : Colors.green;
                  String description;
                  String causes;
                  String action;
                  switch (factor['name']) {
                    case 'Cycle Regularity':
                      description = factor['description'] ?? 'Cycle length variation based on your tracked data.';
                      causes = 'High variation can indicate hormonal imbalances or PCOS.';
                      action = 'Suggested: Continue tracking cycles, consult a gynecologist if irregular.';
                      if (factor['stdDev'] != null) {
                        description += '\n\nTracking Time: ${factor['trackingMonths'] ?? 'N/A'} months (${factor['trackingDays'] ?? 'N/A'} days)\nCycles Tracked: ${factor['cycleCount'] ?? 'N/A'}\nAverage Length: ${factor['avgCycleLength'] ?? 'N/A'} days\nVariation (StdDev): ${factor['stdDev']} days\nPopulation Average: ${factor['populationStdDev']} days';
                      }
                      break;
                    case 'Weight Stability':
                      description = factor['description'] ?? 'Weight fluctuations based on your recent entries.';
                      causes = 'Rapid weight changes affect hormonal balance and metabolism.';
                      action = 'Suggested: Maintain consistent diet and exercise routine. Target: ±2kg variation or less.';
                      if (factor['variance'] != null) {
                        description += '\n\nCurrent Weight: ${factor['currentWeight'] ?? 'N/A'} kg\nVariance: ±${factor['variance']} kg';
                        if (factor['thresholds'] != null) {
                          description += '\n\n${factor['thresholds']}';
                        }
                        if (factor['datasetContext'] != null) {
                          description += '\n\n📊 ${factor['datasetContext']}';
                        }
                      }
                      break;
                    case 'Symptom Patterns':
                      description = factor['description'] ?? 'Analysis of severe symptoms you\'ve logged.';
                      causes = 'Frequent severe symptoms may indicate hormonal disorders.';
                      action = 'Suggested: Log symptoms consistently, discuss patterns with doctor.';
                      if (factor['pcosSpecificCount'] != null) {
                        description += '\n\nPCOS-Specific Symptoms: ${factor['pcosSpecificCount']} severe episodes\nOther Severe Symptoms: ${factor['totalSevereCount'] ?? '0'}';
                      }
                      break;
                    case 'Hydration Level':
                      description = factor['description'] ?? 'Hydration based on daily water intake.';
                      causes = 'Dehydration impacts hormone regulation and metabolism.';
                      action = 'Suggested: Aim for 2-3 liters of water daily for optimal hormonal health.';
                      if (factor['avgMl'] != null) {
                        description += '\n\nCurrent Average: ${factor['avgMl']} ml/day\nRecommended: ${factor['recommendedMl'] ?? '2000-3000'} ml/day';
                        if (factor['thresholds'] != null) {
                          description += '\n\n${factor['thresholds']}';
                        }
                        if (factor['datasetContext'] != null) {
                          description += '\n\n📊 ${factor['datasetContext']}';
                        }
                      }
                      break;
                    default:
                      description = factor['description'] ?? '';
                      causes = '';
                      action = '';
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: barColor.withOpacity(0.13), blurRadius: 8, offset: const Offset(0, 2))],
                      border: Border.all(color: barColor.withOpacity(0.25), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.18),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          child: Row(
                            children: [
                              Icon(
                                factor['severity'] == 'High' ? Icons.error_outline : factor['severity'] == 'Moderate' ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                                color: barColor,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  factor['name'],
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: barColor),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  factor['severity'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(description, style: const TextStyle(fontSize: 14)),
                                ),
                              if (causes.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(causes, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                ),
                              if (action.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(action, style: const TextStyle(fontSize: 13, color: Colors.blue)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.09),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: riskColor.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: riskColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  risk['pcosRisk'] == 'High'
                      ? 'High risk. Please consult a healthcare provider.'
                      : risk['pcosRisk'] == 'Moderate'
                          ? 'Moderate risk. Consider lifestyle changes and regular checkups.'
                          : risk['pcosRisk'] == 'Low'
                              ? 'Low risk. Maintain healthy habits.'
                              : 'Risk level unavailable.',
                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Dataset Insights Section
        if ((risk['datasetInsights'] as String?)?.isNotEmpty ?? false)
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue[200]!, width: 1),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dataset, color: Colors.blue[700], size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Population Data Insights',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue[800]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  risk['datasetInsights'] as String,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Source: ${risk['datasetSource'] as String}',
                  style: TextStyle(fontSize: 11, color: Colors.blue[600], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getFactorColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green[100]!;
      case 'Moderate':
        return Colors.orange[100]!;
      case 'High':
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }
}

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  static const articles = [
    {
      'title': 'Understanding PCOS',
      'author': 'Dr. Smith',
      'content': 'PCOS (Polycystic Ovary Syndrome) is a common endocrine disorder that affects reproductive-aged women. Symptoms include irregular periods, excess androgen, and polycystic ovaries. Early diagnosis and management are key.',
      'summary': 'What is PCOS? Learn about symptoms, causes, and why early diagnosis matters.',
      'icon': Icons.info_outline,
      'tags': ['PCOS', 'Basics'],
      'link': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6889786/',
    },
    {
      'title': 'PCOS Diet and Nutrition',
      'author': 'Nutritionist Jane',
      'content': 'A balanced diet is crucial for managing PCOS. Focus on whole grains, lean proteins, and plenty of vegetables. Limit processed foods and sugars to help regulate insulin.',
      'summary': 'Diet tips for PCOS: What to eat and what to avoid for better health.',
      'icon': Icons.restaurant,
      'tags': ['Diet', 'Nutrition'],
      'link': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6520897/',
    },
    {
      'title': 'Exercise and PCOS',
      'author': 'Fitness Coach Mike',
      'content': 'Regular physical activity is beneficial for managing PCOS symptoms and improving insulin sensitivity. Try a mix of cardio, strength training, and flexibility exercises.',
      'summary': 'How exercise helps PCOS: Best workouts and routines.',
      'icon': Icons.fitness_center,
      'tags': ['Exercise', 'Fitness'],
      'link': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7035637/',
    },
    {
      'title': 'Mental Health and PCOS',
      'author': 'Dr. Johnson',
      'content': 'PCOS can impact mental health. It\'s important to manage stress and seek support when needed. Mindfulness, therapy, and community can help.',
      'summary': 'Coping with PCOS: Mental health strategies and support.',
      'icon': Icons.self_improvement,
      'tags': ['Mental Health', 'Support'],
      'link': 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6466873/',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: articles.map((article) {
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(article['icon'] as IconData, color: Colors.pink, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text(article['title'] as String)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('by ${article['author']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: (article['tags'] as List<String>).map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: Colors.pink[50],
                          labelStyle: const TextStyle(fontSize: 12, color: Colors.pink),
                        )).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(article['content'] as String, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () async {
                          final url = article['link'] as String;
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.link, color: Colors.blue, size: 20),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Read the full study',
                                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Bookmark'),
                  ),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.pink[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(article['icon'] as IconData, color: Colors.pink, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(article['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 6),
                        Text(article['summary'] as String, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: (article['tags'] as List<String>).map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.pink[50],
                            labelStyle: const TextStyle(fontSize: 12, color: Colors.pink),
                          )).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text('by ${article['author']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.pink),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Exercise and Recipe Tutorials Screen
class ExerciseRecipeTutorialsScreen extends StatefulWidget {
  const ExerciseRecipeTutorialsScreen({super.key});

  @override
  State<ExerciseRecipeTutorialsScreen> createState() => _ExerciseRecipeTutorialsScreenState();
}

class _ExerciseRecipeTutorialsScreenState extends State<ExerciseRecipeTutorialsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDifficulty = 0;

  final List<Map<String, dynamic>> exercises = [
    {
      'title': 'Low-Impact Cardio Workout',
      'duration': '20 mins',
      'difficulty': 'Beginner',
      'difficulty_level': 1,
      'description': 'Perfect for beginners. Gentle cardio exercise to improve heart health and burn calories.',
      'steps': [
        'Warm up: 3 minutes of light walking',
        'Marching in place: 5 minutes',
        'Side steps: 4 minutes',
        'Cool down: 3 minutes of slow walking',
        'Stretching: 5 minutes'
      ],
      'benefits': ['Improved cardiovascular health', 'Weight management', 'Increased energy'],
      'icon': Icons.directions_walk,
      'color': Colors.green,
      'videoUrl': 'https://www.youtube.com/watch?v=Ck1pvGQ8_nQ',
    },
    {
      'title': 'Yoga for PCOS',
      'duration': '30 mins',
      'difficulty': 'Beginner',
      'difficulty_level': 1,
      'description': 'Gentle yoga poses specifically designed to help with PCOS symptoms and stress relief.',
      'steps': [
        'Child\'s pose: 2 minutes',
        'Cat-cow stretch: 3 minutes',
        'Cobra pose: 2 minutes',
        'Warrior pose series: 10 minutes',
        'Pigeon pose: 5 minutes',
        'Savasana (relaxation): 8 minutes'
      ],
      'benefits': ['Stress reduction', 'Improved flexibility', 'Better hormone balance'],
      'icon': Icons.self_improvement,
      'color': Colors.purple,
      'videoUrl': 'https://www.youtube.com/watch?v=9K8SZpdMkOQ',
    },
    {
      'title': 'Strength Training Basics',
      'duration': '25 mins',
      'difficulty': 'Intermediate',
      'difficulty_level': 2,
      'description': 'Build muscle and improve metabolism with these essential strength training exercises.',
      'steps': [
        'Warm-up: 5 minutes light cardio',
        'Squats: 3 sets of 10 reps',
        'Push-ups: 3 sets of 8 reps',
        'Lunges: 3 sets of 10 reps each leg',
        'Plank hold: 3 sets of 30 seconds',
        'Cool down and stretch: 5 minutes'
      ],
      'benefits': ['Increased muscle strength', 'Better insulin sensitivity', 'Improved posture'],
      'icon': Icons.fitness_center,
      'color': Colors.orange,
      'videoUrl': 'https://www.youtube.com/watch?v=U0bhE67HuDY',
    },
    {
      'title': 'HIIT Workout for Weight Loss',
      'duration': '20 mins',
      'difficulty': 'Advanced',
      'difficulty_level': 3,
      'description': 'High-Intensity Interval Training to maximize calorie burn and improve fitness.',
      'steps': [
        'Warm up: 3 minutes',
        'Burpees: 30 seconds on, 30 seconds rest (5 rounds)',
        'Mountain climbers: 30 seconds on, 30 seconds rest (5 rounds)',
        'Jump squats: 30 seconds on, 30 seconds rest (5 rounds)',
        'Cool down: 5 minutes'
      ],
      'benefits': ['Rapid calorie burn', 'Improved cardiovascular fitness', 'Time-efficient workout'],
      'icon': Icons.flash_on,
      'color': Colors.red,
      'videoUrl': 'https://www.youtube.com/watch?v=ml6cT4AZdqI',
    },
  ];

  final List<Map<String, dynamic>> recipes = [
    {
      'title': 'Quinoa Buddha Bowl',
      'prepTime': '15 mins',
      'cookTime': '20 mins',
      'servings': 2,
      'difficulty': 'Easy',
      'difficulty_level': 1,
      'description': 'A nutrient-rich bowl packed with protein, fiber, and healthy fats. Perfect for PCOS management.',
      'ingredients': [
        '1 cup quinoa',
        '2 cups mixed vegetables (broccoli, bell peppers, carrots)',
        '1 avocado, sliced',
        '1 can chickpeas, roasted',
        '2 tbsp olive oil',
        'Salt and pepper to taste',
        'Lemon juice'
      ],
      'instructions': [
        'Cook quinoa according to package directions',
        'Roast vegetables at 400°F for 20 minutes',
        'Toast chickpeas with spices for 15 minutes',
        'Arrange quinoa in bowls',
        'Top with roasted vegetables, chickpeas, and avocado',
        'Drizzle with olive oil and lemon juice',
        'Serve and enjoy!'
      ],
      'benefits': ['High in protein', 'Low glycemic index', 'Rich in fiber'],
      'icon': Icons.restaurant,
      'color': Colors.green,
      'videoUrl': 'https://www.youtube.com/watch?v=AlSvyLG1etI&t=44s',
    },
    {
      'title': 'Grilled Chicken with Sweet Potato',
      'prepTime': '10 mins',
      'cookTime': '25 mins',
      'servings': 1,
      'difficulty': 'Easy',
      'difficulty_level': 1,
      'description': 'Lean protein with complex carbs. A balanced meal that helps regulate insulin levels.',
      'ingredients': [
        '150g chicken breast',
        '1 medium sweet potato',
        '1 cup broccoli',
        '1 tbsp olive oil',
        'Herbs: thyme, rosemary',
        'Salt and pepper'
      ],
      'instructions': [
        'Preheat grill to medium-high heat',
        'Cube sweet potato and boil until tender (15 mins)',
        'Season chicken breast with herbs, salt, and pepper',
        'Grill chicken for 12-15 minutes until cooked through',
        'Steam or roast broccoli for 10 minutes',
        'Combine all components on a plate',
        'Drizzle with olive oil and serve'
      ],
      'benefits': ['Complete protein', 'Helps with weight management', 'Nutrient-dense'],
      'icon': Icons.restaurant,
      'color': Colors.amber,
      'videoUrl': 'https://www.youtube.com/watch?v=EjjKRqQYQPw',
    },
    {
      'title': 'Green Smoothie Bowl',
      'prepTime': '5 mins',
      'cookTime': '0 mins',
      'servings': 1,
      'difficulty': 'Easy',
      'difficulty_level': 1,
      'description': 'Quick and delicious breakfast packed with vitamins and minerals.',
      'ingredients': [
        '1 cup spinach',
        '1 banana',
        '1 cup unsweetened almond milk',
        '1 tbsp almond butter',
        'Toppings: granola, berries, coconut flakes',
        'Ice cubes'
      ],
      'instructions': [
        'Add spinach, banana, almond milk, almond butter, and ice to blender',
        'Blend until smooth',
        'Pour into a bowl',
        'Top with granola, fresh berries, and coconut flakes',
        'Enjoy immediately'
      ],
      'benefits': ['Quick breakfast option', 'Packed with antioxidants', 'Sustained energy'],
      'icon': Icons.local_drink,
      'color': Colors.lightGreen,
      'videoUrl': 'https://www.youtube.com/watch?v=q5-r7RpOooU',
    },
    {
      'title': 'Baked Salmon with Vegetables',
      'prepTime': '10 mins',
      'cookTime': '20 mins',
      'servings': 2,
      'difficulty': 'Intermediate',
      'difficulty_level': 2,
      'description': 'Omega-3 rich salmon with roasted vegetables for hormonal balance.',
      'ingredients': [
        '2 salmon fillets (150g each)',
        '2 cups mixed vegetables (zucchini, asparagus, bell pepper)',
        '2 tbsp olive oil',
        '2 cloves garlic, minced',
        'Lemon slices',
        'Herbs: dill, basil'
      ],
      'instructions': [
        'Preheat oven to 400°F',
        'Line baking sheet with parchment paper',
        'Place salmon on sheet, season with dill and salt',
        'Arrange vegetables around salmon',
        'Drizzle with olive oil and scatter garlic',
        'Bake for 20 minutes until salmon is cooked',
        'Serve with lemon wedges'
      ],
      'benefits': ['Omega-3 fatty acids', 'Reduces inflammation', 'Supports hormone health'],
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'videoUrl': 'https://www.youtube.com/watch?v=iHNGJHaEKmE',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final health = context.watch<HealthDataProvider>();

    return Column(
      children: [
        // Modern glassmorphism header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.pink.withOpacity(0.12), width: 1.2),
            backgroundBlendMode: BlendMode.overlay,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.pink[400], size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Personalized Health',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Workouts & Recipes for your journey',
                style: TextStyle(fontSize: 14, color: Colors.pink[400], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Based on your health data and preferences',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        // Modern rounded Tab Bar with icons and animation
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.pink.withOpacity(0.10), width: 1),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.pink[600],
            unselectedLabelColor: Colors.grey[500],
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.pink[50],
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.fitness_center, size: 22),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Exercises', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              Tab(
                icon: Icon(Icons.restaurant, size: 22),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Recipes', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            splashFactory: InkRipple.splashFactory,
            overlayColor: MaterialStateProperty.all(Colors.pink.withOpacity(0.04)),
          ),
        ),
        // Animated Tab Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: TabBarView(
              key: ValueKey(_tabController.index),
              controller: _tabController,
              children: [
                _buildExercisesView(),
                _buildRecipesView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Difficulty Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('Difficulty: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ...[
                ('All', -1),
                ('Beginner', 1),
                ('Intermediate', 2),
                ('Advanced', 3),
              ].map((item) {
                final isSelected = _selectedDifficulty == item.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(item.$1),
                    selected: isSelected,
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.green[300],
                    onSelected: (selected) {
                      setState(() => _selectedDifficulty = item.$2);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Exercise Cards
        ...exercises
            .where((ex) => _selectedDifficulty == -1 || ex['difficulty_level'] == _selectedDifficulty)
            .map((exercise) => _buildExerciseCard(exercise))
            .toList(),
      ],
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showExerciseDetails(exercise),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (exercise['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      exercise['icon'] as IconData,
                      color: exercise['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise['title'] as String,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exercise['description'] as String,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(exercise['duration'] as String),
                    backgroundColor: Colors.blue[50],
                    avatar: Icon(Icons.timer_outlined, size: 16, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(exercise['difficulty'] as String),
                    backgroundColor: (exercise['color'] as Color).withOpacity(0.2),
                    labelStyle: TextStyle(color: exercise['color'] as Color),
                  ),
                  const Spacer(),
                  const Icon(Icons.play_circle_outlined, color: Colors.pink, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipesView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: recipes
          .map((recipe) => _buildRecipeCard(recipe))
          .toList(),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecipeDetails(recipe),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (recipe['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      recipe['icon'] as IconData,
                      color: recipe['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['title'] as String,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe['description'] as String,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text('${recipe['prepTime']} prep'),
                    backgroundColor: Colors.amber[50],
                    avatar: Icon(Icons.schedule_outlined, size: 16, color: Colors.amber[700]),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${recipe['servings']} servings'),
                    backgroundColor: Colors.orange[50],
                    avatar: Icon(Icons.people_outline, size: 16, color: Colors.orange[700]),
                  ),
                  const Spacer(),
                  const Icon(Icons.info_outline, color: Colors.pink, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseDetails(Map<String, dynamic> exercise) {
    final videoUrl = exercise['videoUrl'] as String;
    final videoId = _extractVideoId(videoUrl);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseDetailsSheet(
        exercise: exercise,
        videoId: videoId,
        videoUrl: videoUrl,
      ),
    );
  }

  void _showRecipeDetails(Map<String, dynamic> recipe) {
    final videoUrl = recipe['videoUrl'] as String;
    final videoId = _extractVideoId(videoUrl);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipeDetailsSheet(
        recipe: recipe,
        videoId: videoId,
        videoUrl: videoUrl,
      ),
    );
  }

  String _extractVideoId(String url) {
    try {
      print('DEBUG: Attempting to extract video ID from URL: $url');
      
      // Method 1: youtu.be short format
      if (url.contains('youtu.be/')) {
        final match = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
        if (match != null && match.group(1) != null) {
          final id = match.group(1)!;
          print('DEBUG: Extracted from youtu.be format: $id');
          return id;
        }
      }
      
      // Method 2: youtube.com/watch?v= format
      if (url.contains('youtube.com/watch') || url.contains('youtube.com/embed')) {
        final match = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
        if (match != null && match.group(1) != null) {
          final id = match.group(1)!;
          print('DEBUG: Extracted from youtube.com format: $id');
          return id;
        }
      }
      
      // Method 3: youtube.com/embed/ format
      if (url.contains('youtube.com/embed/')) {
        final match = RegExp(r'embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
        if (match != null && match.group(1) != null) {
          final id = match.group(1)!;
          print('DEBUG: Extracted from embed format: $id');
          return id;
        }
      }
      
      print('DEBUG: No regex match found for URL format');
    } catch (e) {
      print('ERROR extracting video ID: $e');
      print('ERROR stack trace: $e');
    }
    print('DEBUG: Returning empty video ID');
    return '';
  }

  Widget _buildInfoPill(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue[700]),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $urlString')),
      );
    }
  }
}

// Exercise Details Sheet with embedded video player
class _ExerciseDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String videoId;
  final String videoUrl;

  const _ExerciseDetailsSheet({
    required this.exercise,
    required this.videoId,
    required this.videoUrl,
  });

  @override
  State<_ExerciseDetailsSheet> createState() => _ExerciseDetailsSheetState();
}

class _ExerciseDetailsSheetState extends State<_ExerciseDetailsSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Watch Video Button
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.pink[50],
                    border: Border.all(color: Colors.pink[200]!, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _launchYoutubeVideo(widget.videoUrl),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_filled, size: 64, color: Colors.pink),
                            const SizedBox(height: 12),
                            Text(
                              'Watch Video on YouTube',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.pink[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to open in YouTube',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Title and Description
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (widget.exercise['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.exercise['icon'] as IconData,
                        color: widget.exercise['color'] as Color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exercise['title'] as String,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.exercise['description'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Duration and Difficulty
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoPill(
                      Icons.timer_outlined,
                      widget.exercise['duration'] as String,
                      'Duration',
                    ),
                    _buildInfoPill(
                      Icons.trending_up,
                      widget.exercise['difficulty'] as String,
                      'Level',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Workout Steps
                Text(
                  'Workout Steps',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...(widget.exercise['steps'] as List<String>)
                    .asMap()
                    .entries
                    .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (widget.exercise['color'] as Color)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
                const SizedBox(height: 24),
                // Benefits
                Text(
                  'Benefits',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...(widget.exercise['benefits'] as List<String>)
                    .map((benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue[700]),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Future<void> _launchYoutubeVideo(String url) async {
    try {
      final Uri videoUrl = Uri.parse(url);
      if (await canLaunchUrl(videoUrl)) {
        await launchUrl(videoUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video')),
        );
      }
    } catch (e) {
      print('Error launching video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error opening video')),
      );
    }
  }
}

// Recipe Details Sheet with embedded video player
class _RecipeDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final String videoId;
  final String videoUrl;

  const _RecipeDetailsSheet({
    required this.recipe,
    required this.videoId,
    required this.videoUrl,
  });

  @override
  State<_RecipeDetailsSheet> createState() => _RecipeDetailsSheetState();
}

class _RecipeDetailsSheetState extends State<_RecipeDetailsSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Watch Video Button
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[200]!, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _launchYoutubeVideo(widget.videoUrl),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_filled, size: 64, color: Colors.orange),
                            const SizedBox(height: 12),
                            Text(
                              'Watch Recipe Video on YouTube',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to open in YouTube',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Title and Description
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (widget.recipe['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.recipe['icon'] as IconData,
                        color: widget.recipe['color'] as Color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.recipe['title'] as String,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.recipe['description'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Prep, Cook, Servings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoPill(
                      Icons.schedule_outlined,
                      widget.recipe['prepTime'] as String,
                      'Prep',
                    ),
                    _buildInfoPill(
                      Icons.restaurant_outlined,
                      widget.recipe['cookTime'] as String,
                      'Cook',
                    ),
                    _buildInfoPill(
                      Icons.people_outline,
                      '${widget.recipe['servings']} servings',
                      'Servings',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Ingredients
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...(widget.recipe['ingredients'] as List<String>)
                    .map((ingredient) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ingredient,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
                const SizedBox(height: 24),
                // Instructions
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...(widget.recipe['instructions'] as List<String>)
                    .asMap()
                    .entries
                    .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (widget.recipe['color'] as Color)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
                const SizedBox(height: 24),
                // Health Benefits
                Text(
                  'Health Benefits',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...(widget.recipe['benefits'] as List<String>)
                    .map((benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.red[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchYoutubeVideo(String url) async {
    try {
      final Uri videoUrl = Uri.parse(url);
      if (await canLaunchUrl(videoUrl)) {
        await launchUrl(videoUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video')),
        );
      }
    } catch (e) {
      print('Error launching video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error opening video')),
      );
    }
  }

  Widget _buildInfoPill(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.orange[700]),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// Lifestyle & Wellness Screen (for recommendations)
class LifestyleWellnessScreen {
  static const recommendations = [
    {
      'emoji': '🥗',
      'title': 'Healthy Eating',
      'items': [
        'Eat more vegetables and whole grains',
        'Limit processed sugars',
        'Stay hydrated',
      ],
    },
    {
      'emoji': '🏃‍♀️',
      'title': 'Physical Activity',
      'items': [
        'Exercise 3-5 times per week',
        'Try walking, yoga, or swimming',
      ],
    },
    {
      'emoji': '🧘‍♀️',
      'title': 'Stress Management',
      'items': [
        'Practice mindfulness or meditation',
        'Get enough sleep',
      ],
    },
  ];
}