import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/kaggle_config.dart';

/// Exception thrown when Kaggle API request fails
class KaggleApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  
  KaggleApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });
  
  @override
  String toString() => 'KaggleApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Kaggle API Client
/// 
/// Handles authentication and communication with Kaggle API
class KaggleApiClient {
  final http.Client _httpClient;
  late final String _basicAuth;
  
  KaggleApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client() {
    _initializeAuth();
  }
  
  /// Initialize authentication header
  void _initializeAuth() {
    try {
      KaggleConfig.validate();
      _basicAuth = base64Encode(
        utf8.encode('${KaggleConfig.username}:${KaggleConfig.apiKey}')
      );
    } catch (e) {
      throw KaggleApiException(message: 'Failed to initialize Kaggle authentication: $e');
    }
  }
  
  /// Get authorization headers
  Map<String, String> get _headers => {
    'Authorization': 'Basic $_basicAuth',
    'Content-Type': 'application/json',
  };
  
  /// List datasets
  /// 
  /// [query] - Optional search query
  /// [sortBy] - Sort order (hotness, helpful, views, newest)
  /// [page] - Page number (default: 1)
  /// [pageSize] - Results per page (default: 20)
  Future<List<Map<String, dynamic>>> listDatasets({
    String? query,
    String sortBy = 'hotness',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      String url = '${KaggleConfig.baseUrl}/datasets/list?sort_by=$sortBy&page=$page&page_size=$pageSize';
      
      if (query != null && query.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(query)}';
      }
      
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(KaggleConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw KaggleApiException(
          message: 'Authentication failed. Check your Kaggle credentials.',
          statusCode: 401,
          responseBody: response.body,
        );
      } else if (response.statusCode == 429) {
        throw KaggleApiException(
          message: 'Too many requests. Please wait before trying again.',
          statusCode: 429,
        );
      } else {
        throw KaggleApiException(
          message: 'Failed to list datasets',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on KaggleApiException {
      rethrow;
    } catch (e) {
      throw KaggleApiException(
        message: 'Error listing datasets: $e',
      );
    }
  }
  
  /// Get dataset details
  /// 
  /// [datasetRef] - Dataset reference (owner/dataset-name)
  Future<Map<String, dynamic>> getDataset(String datasetRef) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${KaggleConfig.baseUrl}/datasets/view/$datasetRef'),
        headers: _headers,
      ).timeout(KaggleConfig.timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        throw KaggleApiException(
          message: 'Dataset not found: $datasetRef',
          statusCode: 404,
        );
      } else {
        throw KaggleApiException(
          message: 'Failed to get dataset: $datasetRef',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on KaggleApiException {
      rethrow;
    } catch (e) {
      throw KaggleApiException(
        message: 'Error getting dataset: $e',
      );
    }
  }
  
  /// Download dataset file
  /// 
  /// [datasetRef] - Dataset reference (owner/dataset-name)
  /// [fileName] - Specific file to download (optional)
  Future<List<int>> downloadDataset(
    String datasetRef, {
    String? fileName,
  }) async {
    try {
      String url = '${KaggleConfig.baseUrl}/datasets/download/$datasetRef';
      if (fileName != null) {
        url += '?datasetVersionNumber=latest&fileName=${Uri.encodeComponent(fileName)}';
      }
      
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(KaggleConfig.timeout);
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw KaggleApiException(
          message: 'Failed to download dataset: $datasetRef',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on KaggleApiException {
      rethrow;
    } catch (e) {
      throw KaggleApiException(
        message: 'Error downloading dataset: $e',
      );
    }
  }
  
  /// Get API usage info
  Future<Map<String, dynamic>> getApiUsage() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${KaggleConfig.baseUrl}/users/view/me'),
        headers: _headers,
      ).timeout(KaggleConfig.timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw KaggleApiException(
          message: 'Failed to get API usage info',
          statusCode: response.statusCode,
        );
      }
    } on KaggleApiException {
      rethrow;
    } catch (e) {
      throw KaggleApiException(
        message: 'Error getting API usage: $e',
      );
    }
  }
  
  /// Search datasets
  /// 
  /// [query] - Search query
  /// [maxResults] - Maximum results to return
  Future<List<Map<String, dynamic>>> searchDatasets(
    String query, {
    int maxResults = 20,
  }) async {
    if (query.isEmpty) {
      throw KaggleApiException(message: 'Search query cannot be empty');
    }
    
    return listDatasets(
      query: query,
      pageSize: maxResults,
    );
  }
  
  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}
