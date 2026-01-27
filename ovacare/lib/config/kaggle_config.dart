import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'kaggle_config_provider.dart';

/// Kaggle API Configuration
/// 
/// This class manages Kaggle API credentials and settings.
/// 
/// IMPORTANT: Never hardcode credentials in your code!
/// 
/// Setup instructions:
/// 1. Go to https://www.kaggle.com/account
/// 2. Scroll down to "API" section
/// 3. Click "Create New API Token" - this downloads kaggle.json
/// 4. Create .env file in project root with credentials
/// 
/// Example .env file:
/// KAGGLE_USERNAME=your_username
/// KAGGLE_KEY=your_api_key
class KaggleConfig {
  /// Kaggle API username
  /// Loaded from test credentials, environment variables, or --dart-define
  static String get username {
    // Use provider to get credentials from various sources
    final providedUsername = KaggleConfigProvider.getUsername();
    if (providedUsername.isNotEmpty) {
      return providedUsername;
    }

    // Fallback to dotenv if available
    try {
      final dotenvValue = dotenv.env['KAGGLE_USERNAME'];
      if (dotenvValue != null && dotenvValue.isNotEmpty) {
        return dotenvValue;
      }
    } catch (_) {
      // dotenv not initialized
    }

    return '';
  }
  
  /// Kaggle API key
  /// Loaded from test credentials, environment variables, or --dart-define
  static String get apiKey {
    // Use provider to get credentials from various sources
    final providedKey = KaggleConfigProvider.getApiKey();
    if (providedKey.isNotEmpty) {
      return providedKey;
    }

    // Fallback to dotenv if available
    try {
      final dotenvValue = dotenv.env['KAGGLE_KEY'];
      if (dotenvValue != null && dotenvValue.isNotEmpty) {
        return dotenvValue;
      }
    } catch (_) {
      // dotenv not initialized
    }

    return '';
  }
  
  /// Kaggle API base URL
  static const String baseUrl = 'https://www.kaggle.com/api/v1';
  
  /// Request timeout duration
  static const Duration timeout = Duration(seconds: 30);
  
  /// Check if credentials are properly configured
  static bool get isConfigured {
    return username.isNotEmpty && apiKey.isNotEmpty;
  }
  
  /// Get configuration status message
  static String getConfigStatus() {
    if (!isConfigured) {
      return 'Kaggle API credentials not configured. Set KAGGLE_USERNAME and KAGGLE_KEY environment variables.';
    }
    return 'Kaggle API is configured and ready to use.';
  }
  
  /// Validate configuration
  /// Throws exception if credentials are invalid
  static void validate() {
    if (!isConfigured) {
      throw KaggleConfigException(
        'Kaggle API credentials not configured.\n'
        'Please set KAGGLE_USERNAME and KAGGLE_KEY environment variables.\n'
        'Get your credentials from: https://www.kaggle.com/account\n'
        'Download your API token (kaggle.json) and extract credentials.'
      );
    }
  }
}

/// Exception thrown when Kaggle configuration is invalid
class KaggleConfigException implements Exception {
  final String message;
  
  KaggleConfigException(this.message);
  
  @override
  String toString() => 'KaggleConfigException: $message';
}
