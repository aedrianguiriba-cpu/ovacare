import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;
  
  // Notification Settings
  bool _systemNotifications = true;
  bool _userReportAlerts = true;
  bool _newUserAlerts = true;
  bool _contentAlerts = true;
  bool _securityAlerts = true;
  bool _emailNotifications = false;
  
  // Privacy Settings
  bool _analyticsEnabled = true;
  bool _activityLogging = true;
  bool _twoFactorAuth = false;
  bool _sessionTimeout = true;
  
  // Getters
  bool get systemNotifications => _systemNotifications;
  bool get userReportAlerts => _userReportAlerts;
  bool get newUserAlerts => _newUserAlerts;
  bool get contentAlerts => _contentAlerts;
  bool get securityAlerts => _securityAlerts;
  bool get emailNotifications => _emailNotifications;
  bool get analyticsEnabled => _analyticsEnabled;
  bool get activityLogging => _activityLogging;
  bool get twoFactorAuth => _twoFactorAuth;
  bool get sessionTimeout => _sessionTimeout;
  
  // Computed getters
  bool get allNotificationsEnabled => 
      _systemNotifications && _userReportAlerts && _newUserAlerts && 
      _contentAlerts && _securityAlerts;
  
  // Initialize
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }
  
  void _loadSettings() {
    _systemNotifications = _prefs?.getBool('admin_systemNotifications') ?? true;
    _userReportAlerts = _prefs?.getBool('admin_userReportAlerts') ?? true;
    _newUserAlerts = _prefs?.getBool('admin_newUserAlerts') ?? true;
    _contentAlerts = _prefs?.getBool('admin_contentAlerts') ?? true;
    _securityAlerts = _prefs?.getBool('admin_securityAlerts') ?? true;
    _emailNotifications = _prefs?.getBool('admin_emailNotifications') ?? false;
    _analyticsEnabled = _prefs?.getBool('admin_analyticsEnabled') ?? true;
    _activityLogging = _prefs?.getBool('admin_activityLogging') ?? true;
    _twoFactorAuth = _prefs?.getBool('admin_twoFactorAuth') ?? false;
    _sessionTimeout = _prefs?.getBool('admin_sessionTimeout') ?? true;
    notifyListeners();
  }
  
  // Setters with persistence
  Future<void> setSystemNotifications(bool value) async {
    _systemNotifications = value;
    await _prefs?.setBool('admin_systemNotifications', value);
    notifyListeners();
  }
  
  Future<void> setUserReportAlerts(bool value) async {
    _userReportAlerts = value;
    await _prefs?.setBool('admin_userReportAlerts', value);
    notifyListeners();
  }
  
  Future<void> setNewUserAlerts(bool value) async {
    _newUserAlerts = value;
    await _prefs?.setBool('admin_newUserAlerts', value);
    notifyListeners();
  }
  
  Future<void> setContentAlerts(bool value) async {
    _contentAlerts = value;
    await _prefs?.setBool('admin_contentAlerts', value);
    notifyListeners();
  }
  
  Future<void> setSecurityAlerts(bool value) async {
    _securityAlerts = value;
    await _prefs?.setBool('admin_securityAlerts', value);
    notifyListeners();
  }
  
  Future<void> setEmailNotifications(bool value) async {
    _emailNotifications = value;
    await _prefs?.setBool('admin_emailNotifications', value);
    notifyListeners();
  }
  
  Future<void> setAnalyticsEnabled(bool value) async {
    _analyticsEnabled = value;
    await _prefs?.setBool('admin_analyticsEnabled', value);
    notifyListeners();
  }
  
  Future<void> setActivityLogging(bool value) async {
    _activityLogging = value;
    await _prefs?.setBool('admin_activityLogging', value);
    notifyListeners();
  }
  
  Future<void> setTwoFactorAuth(bool value) async {
    _twoFactorAuth = value;
    await _prefs?.setBool('admin_twoFactorAuth', value);
    notifyListeners();
  }
  
  Future<void> setSessionTimeout(bool value) async {
    _sessionTimeout = value;
    await _prefs?.setBool('admin_sessionTimeout', value);
    notifyListeners();
  }
  
  // Toggle all notifications
  Future<void> setAllNotifications(bool value) async {
    await setSystemNotifications(value);
    await setUserReportAlerts(value);
    await setNewUserAlerts(value);
    await setContentAlerts(value);
    await setSecurityAlerts(value);
  }
  
  // Reset to defaults
  Future<void> resetToDefaults() async {
    await setSystemNotifications(true);
    await setUserReportAlerts(true);
    await setNewUserAlerts(true);
    await setContentAlerts(true);
    await setSecurityAlerts(true);
    await setEmailNotifications(false);
    await setAnalyticsEnabled(true);
    await setActivityLogging(true);
    await setTwoFactorAuth(false);
    await setSessionTimeout(true);
  }
  
  // Export admin activity log (simulated)
  Future<String> exportActivityLog() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'Admin activity log exported successfully';
  }
}
