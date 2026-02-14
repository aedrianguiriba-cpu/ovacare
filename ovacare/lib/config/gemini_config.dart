import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../gemini_moderation_service.dart';

/// Configuration for Gemini AI integration
class GeminiConfig {
  /// Initialize Gemini with API key from environment
  static void initialize() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (apiKey != null && apiKey.isNotEmpty) {
        GeminiModerationService.initialize(apiKey);
        print('✅ Gemini AI initialized successfully');
      } else {
        GeminiModerationService.initialize(null);
        print('⚠️ Gemini API key not found - using offline mode');
        print('📝 To enable Gemini AI:');
        print('   1. Get free API key at: https://ai.google.dev');
        print('   2. Add to .env file: GEMINI_API_KEY=your_key_here');
      }
    } catch (e) {
      // dotenv not initialized or .env file not found
      GeminiModerationService.initialize(null);
      print('⚠️ Gemini API key not found - using offline mode');
      print('📝 To enable Gemini AI:');
      print('   1. Get free API key at: https://ai.google.dev');
      print('   2. Add to .env file: GEMINI_API_KEY=your_key_here');
    }
  }
  
  /// Check if Gemini is available
  static bool get isAvailable => GeminiModerationService.isAvailable;
  
  /// Get status string
  static String getStatus() {
    return GeminiModerationService.isAvailable 
      ? '🤖 Gemini AI Online' 
      : '📱 Offline Mode (Keyword Analysis)';
  }
}
