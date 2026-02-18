import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingsProvider manages all app settings with persistence
class SettingsProvider extends ChangeNotifier {
  static const String _keyNotifyPeriod = 'notify_period_reminders';
  static const String _keyNotifySymptoms = 'notify_symptom_tracking';
  static const String _keyNotifyMedications = 'notify_medications';
  static const String _keyNotifyHealth = 'notify_health_tips';
  static const String _keyNotifyAppointments = 'notify_appointments';
  
  static const String _keyPrivacyAnalytics = 'privacy_analytics';
  static const String _keyPrivacyDataSharing = 'privacy_data_sharing';
  static const String _keyPrivacyPersonalizedAds = 'privacy_personalized_ads';
  static const String _keyPrivacyLocationAccess = 'privacy_location_access';
  static const String _keyPrivacyHealthSync = 'privacy_health_sync';

  SharedPreferences? _prefs;
  bool _isLoading = true;

  // Notification Settings
  bool _notifyPeriodReminders = true;
  bool _notifySymptomTracking = true;
  bool _notifyMedications = true;
  bool _notifyHealthTips = true;
  bool _notifyAppointments = true;

  // Privacy Settings
  bool _privacyAnalytics = true;
  bool _privacyDataSharing = false;
  bool _privacyPersonalizedAds = false;
  bool _privacyLocationAccess = false;
  bool _privacyHealthSync = true;

  // Getters for Notification Settings
  bool get isLoading => _isLoading;
  bool get notifyPeriodReminders => _notifyPeriodReminders;
  bool get notifySymptomTracking => _notifySymptomTracking;
  bool get notifyMedications => _notifyMedications;
  bool get notifyHealthTips => _notifyHealthTips;
  bool get notifyAppointments => _notifyAppointments;

  // Getters for Privacy Settings
  bool get privacyAnalytics => _privacyAnalytics;
  bool get privacyDataSharing => _privacyDataSharing;
  bool get privacyPersonalizedAds => _privacyPersonalizedAds;
  bool get privacyLocationAccess => _privacyLocationAccess;
  bool get privacyHealthSync => _privacyHealthSync;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load Notification Settings
    _notifyPeriodReminders = _prefs?.getBool(_keyNotifyPeriod) ?? true;
    _notifySymptomTracking = _prefs?.getBool(_keyNotifySymptoms) ?? true;
    _notifyMedications = _prefs?.getBool(_keyNotifyMedications) ?? true;
    _notifyHealthTips = _prefs?.getBool(_keyNotifyHealth) ?? true;
    _notifyAppointments = _prefs?.getBool(_keyNotifyAppointments) ?? true;

    // Load Privacy Settings
    _privacyAnalytics = _prefs?.getBool(_keyPrivacyAnalytics) ?? true;
    _privacyDataSharing = _prefs?.getBool(_keyPrivacyDataSharing) ?? false;
    _privacyPersonalizedAds = _prefs?.getBool(_keyPrivacyPersonalizedAds) ?? false;
    _privacyLocationAccess = _prefs?.getBool(_keyPrivacyLocationAccess) ?? false;
    _privacyHealthSync = _prefs?.getBool(_keyPrivacyHealthSync) ?? true;

    _isLoading = false;
    notifyListeners();
  }

  // Notification Setters
  Future<void> setNotifyPeriodReminders(bool value) async {
    _notifyPeriodReminders = value;
    await _prefs?.setBool(_keyNotifyPeriod, value);
    notifyListeners();
  }

  Future<void> setNotifySymptomTracking(bool value) async {
    _notifySymptomTracking = value;
    await _prefs?.setBool(_keyNotifySymptoms, value);
    notifyListeners();
  }

  Future<void> setNotifyMedications(bool value) async {
    _notifyMedications = value;
    await _prefs?.setBool(_keyNotifyMedications, value);
    notifyListeners();
  }

  Future<void> setNotifyHealthTips(bool value) async {
    _notifyHealthTips = value;
    await _prefs?.setBool(_keyNotifyHealth, value);
    notifyListeners();
  }

  Future<void> setNotifyAppointments(bool value) async {
    _notifyAppointments = value;
    await _prefs?.setBool(_keyNotifyAppointments, value);
    notifyListeners();
  }

  // Privacy Setters
  Future<void> setPrivacyAnalytics(bool value) async {
    _privacyAnalytics = value;
    await _prefs?.setBool(_keyPrivacyAnalytics, value);
    notifyListeners();
  }

  Future<void> setPrivacyDataSharing(bool value) async {
    _privacyDataSharing = value;
    await _prefs?.setBool(_keyPrivacyDataSharing, value);
    notifyListeners();
  }

  Future<void> setPrivacyPersonalizedAds(bool value) async {
    _privacyPersonalizedAds = value;
    await _prefs?.setBool(_keyPrivacyPersonalizedAds, value);
    notifyListeners();
  }

  Future<void> setPrivacyLocationAccess(bool value) async {
    _privacyLocationAccess = value;
    await _prefs?.setBool(_keyPrivacyLocationAccess, value);
    notifyListeners();
  }

  Future<void> setPrivacyHealthSync(bool value) async {
    _privacyHealthSync = value;
    await _prefs?.setBool(_keyPrivacyHealthSync, value);
    notifyListeners();
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    // Reset Notification Settings
    _notifyPeriodReminders = true;
    _notifySymptomTracking = true;
    _notifyMedications = true;
    _notifyHealthTips = true;
    _notifyAppointments = true;

    // Reset Privacy Settings
    _privacyAnalytics = true;
    _privacyDataSharing = false;
    _privacyPersonalizedAds = false;
    _privacyLocationAccess = false;
    _privacyHealthSync = true;

    // Clear all stored preferences
    await _prefs?.clear();
    notifyListeners();
  }

  // Export user data (for privacy compliance)
  Map<String, dynamic> exportUserData() {
    return {
      'notification_settings': {
        'period_reminders': _notifyPeriodReminders,
        'symptom_tracking': _notifySymptomTracking,
        'medications': _notifyMedications,
        'health_tips': _notifyHealthTips,
        'appointments': _notifyAppointments,
      },
      'privacy_settings': {
        'analytics': _privacyAnalytics,
        'data_sharing': _privacyDataSharing,
        'personalized_ads': _privacyPersonalizedAds,
        'location_access': _privacyLocationAccess,
        'health_sync': _privacyHealthSync,
      },
      'exported_at': DateTime.now().toIso8601String(),
    };
  }
}
