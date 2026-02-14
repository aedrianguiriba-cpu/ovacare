import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// Free AI moderation using Google Gemini API
/// Get free API key at: https://ai.google.dev
class GeminiModerationService {
  static const String _geminiModel = 'gemini-3-flash-preview';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  static String? _apiKey;

  /// Initialize with API key (can be empty for fallback mode)
  static void initialize(String? apiKey) {
    _apiKey = apiKey;
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      print('✅ Gemini API Key loaded');
    }
  }

  /// Check if API is available
  static bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;

  /// Analyze forum post using Gemini AI
  static Future<Map<String, dynamic>> analyzePostAI(String title, String content) async {
    if (!isAvailable) {
      print('ℹ️ Offline mode - no API key');
      return _getFallbackResponse();
    }

    try {
      print('🤖 Calling Gemini...');
      final response = await _callGeminiAPI(title, content).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('⏱️ Gemini timeout');
          return _getFallbackResponse();
        },
      );
      return response;
    } catch (e) {
      print('❌ Gemini error: $e');
      return _getFallbackResponse();
    }
  }

  /// Call Gemini API with correct v1 format
  static Future<Map<String, dynamic>> _callGeminiAPI(String title, String content) async {
    // Enhanced prompt that explicitly handles Tagalog/Filipino and other languages
    final prompt = '''Analyze this forum post for a PCOS (Polycystic Ovary Syndrome) health community app.

IMPORTANT: The post may be in English, Tagalog/Filipino, Taglish (mixed English-Tagalog), or other languages. 
You MUST detect the language and understand PCOS-related content in ANY language.

Common Tagalog PCOS terms to recognize:
- "irregular na regla/period" (irregular menstruation)
- "hindi regular ang regla" (irregular period)  
- "walang regla/period" (missed period)
- "mabigat na regla" (heavy period)
- "masakit ang puson" (abdominal pain)
- "hormonal imbalance" 
- "pagbubuntis/fertility" (pregnancy/fertility)
- "gamot/medication" (medicine)
- "sintomas/symptoms" (symptoms)
- "kista sa ovary" (ovarian cyst)
- "timbang/weight" (weight issues)
- "stress, anxiety, depression"
- "acne, pimples, tigyawat"
- "buhok/hair" (hair issues - hirsutism or hair loss)

Respond with ONLY this JSON format (no extra text):
{"isRelevant":true/false,"confidence":0-100,"isSafe":true/false,"hasPCOS":true/false,"language":"detected_language_code","isTagalog":true/false,"detectedTopics":["topic1","topic2"]}

Where:
- isRelevant: true if post is about PCOS, women's health, fertility, hormones, menstrual health
- confidence: 0-100 how confident you are
- isSafe: true if no harmful/spam content
- hasPCOS: true if specifically mentions PCOS or its symptoms
- language: detected language code (en, tl, tl-en for Taglish, etc.)
- isTagalog: true if post contains Tagalog/Filipino words
- detectedTopics: list of health topics detected (symptoms, treatment, fertility, lifestyle, etc.)

Title: $title
Content: $content''';

    if (_apiKey == null || _apiKey!.isEmpty) {
      print('❌ No API key available');
      return _getFallbackResponse();
    }

    final uri = Uri.parse('$_baseUrl/$_geminiModel:generateContent?key=$_apiKey');
    print('🔗 API URL: ${uri.toString().replaceAll(_apiKey!, 'KEY_HIDDEN')}');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        if (text.isEmpty) {
          print('⚠️ Empty response');
          return _getFallbackResponse();
        }

        print('✅ Got response');

        // Extract JSON
        final jsonMatch = RegExp(r'\{[^{}]*\}').firstMatch(text);
        if (jsonMatch == null) {
          print('⚠️ No JSON found in: $text');
          return _getFallbackResponse();
        }

        try {
          final analysis = jsonDecode(jsonMatch.group(0)!);
          
          // Extract language detection info
          final detectedLanguage = analysis['language'] ?? 'en';
          final isTagalog = (analysis['isTagalog'] ?? false) == true;
          final detectedTopics = (analysis['detectedTopics'] as List?)?.cast<String>() ?? [];
          
          print('🌐 Detected language: $detectedLanguage, Tagalog: $isTagalog');
          if (detectedTopics.isNotEmpty) {
            print('📋 Topics: ${detectedTopics.join(", ")}');
          }
          
          return {
            'language': detectedLanguage,
            'isTagalog': isTagalog,
            'detectedTopics': detectedTopics,
            'isRelevant': (analysis['isRelevant'] ?? false) == true,
            'confidence': ((analysis['confidence'] ?? 0) as num).toDouble(),
            'hasHealthContent': (analysis['hasPCOS'] ?? false) == true,
            'isSafe': (analysis['isSafe'] ?? true) == true,
            'qualityScore': ((analysis['confidence'] ?? 0) as num).toDouble(),
            'entities': [],
            'summary': isTagalog 
                ? 'Gemini analysis complete (Tagalog detected)' 
                : 'Gemini analysis complete',
            'aiSource': '🤖 Gemini',
            'recommendApproval': ((analysis['isRelevant'] ?? false) == true || (analysis['hasPCOS'] ?? false) == true),
          };
        } catch (e) {
          print('JSON error: $e');
          return _getFallbackResponse();
        }
      } else {
        print('❌ HTTP ${response.statusCode}');
        print('📝 Error: ${response.body}');
        return _getFallbackResponse();
      }
    } catch (e) {
      print('Network error: $e');
      return _getFallbackResponse();
    }
  }

  /// Fallback response
  static Map<String, dynamic> _getFallbackResponse() {
    return {
      'language': 'unknown',
      'isTagalog': null,
      'detectedTopics': <String>[],
      'isRelevant': null,
      'confidence': 0.0,
      'hasHealthContent': null,
      'isSafe': true,
      'qualityScore': 0.0,
      'entities': [],
      'summary': 'Offline mode',
      'aiSource': '📱 Offline',
      'recommendApproval': null,
    };
  }

  static Future<void> close() async {}
}

int min(int a, int b) => a < b ? a : b;

