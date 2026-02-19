/// Kaggle Configuration Provider
/// 
/// This class provides a clean way to manage Kaggle API credentials
/// It supports multiple sources of credentials and can be overridden for testing
class KaggleConfigProvider {
  static String? _testUsername;
  static String? _testApiKey;

  /// Set credentials for testing
  static void setTestCredentials(String username, String apiKey) {
    _testUsername = username;
    _testApiKey = apiKey;
  }

  /// Clear test credentials
  static void clearTestCredentials() {
    _testUsername = null;
    _testApiKey = null;
  }

  /// Get Kaggle username from various sources
  static String getUsername() {
    // 1. Check if test credentials are set
    if (_testUsername != null && _testUsername!.isNotEmpty) {
      return _testUsername!;
    }

    // 2. Check environment variable (from --dart-define or system env)
    String envValue = const String.fromEnvironment('KAGGLE_USERNAME');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    return '';
  }

  /// Get Kaggle API key from various sources
  static String getApiKey() {
    // 1. Check if test credentials are set
    if (_testApiKey != null && _testApiKey!.isNotEmpty) {
      return _testApiKey!;
    }

    // 2. Check environment variable (from --dart-define or system env)
    String envValue = const String.fromEnvironment('KAGGLE_KEY');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    return '';
  }
}
