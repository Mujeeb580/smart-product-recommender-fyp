import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';

/// API Service to handle all HTTP requests to the backend
class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // HTTP Client
  final http.Client _client = http.Client();

  /// GET Request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      // Build URI with query parameters
      final uri = Uri.parse(endpoint).replace(
        queryParameters: queryParams?.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );

      final response = await _client
          .get(
            uri,
            headers: headers ?? ApiConfig.headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on HttpException {
      throw ApiException('Service unavailable. Please try again later.');
    } on FormatException {
      throw ApiException('Invalid response format from server.');
    } catch (e) {
      throw ApiException('Error: ${e.toString()}');
    }
  }

  /// POST Request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: headers ?? ApiConfig.headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on HttpException {
      throw ApiException('Service unavailable. Please try again later.');
    } on FormatException {
      throw ApiException('Invalid response format from server.');
    } catch (e) {
      throw ApiException('Error: ${e.toString()}');
    }
  }

  /// PUT Request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse(endpoint),
            headers: headers ?? ApiConfig.headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on HttpException {
      throw ApiException('Service unavailable. Please try again later.');
    } on FormatException {
      throw ApiException('Invalid response format from server.');
    } catch (e) {
      throw ApiException('Error: ${e.toString()}');
    }
  }

  /// DELETE Request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .delete(
            Uri.parse(endpoint),
            headers: headers ?? ApiConfig.headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on HttpException {
      throw ApiException('Service unavailable. Please try again later.');
    } on FormatException {
      throw ApiException('Invalid response format from server.');
    } catch (e) {
      throw ApiException('Error: ${e.toString()}');
    }
  }

  /// Handle HTTP Response
  Map<String, dynamic> _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          throw ApiException('Failed to parse response');
        }

      case 400:
        throw ApiException('Bad request: ${_getErrorMessage(response)}');

      case 401:
        throw ApiException('Unauthorized: ${_getErrorMessage(response)}');

      case 403:
        throw ApiException('Forbidden: ${_getErrorMessage(response)}');

      case 404:
        throw ApiException('Not found: ${_getErrorMessage(response)}');

      case 500:
        throw ApiException('Server error. Please try again later.');

      case 503:
        throw ApiException('Service unavailable. Please try again later.');

      default:
        throw ApiException(
          'Request failed with status: ${response.statusCode}',
        );
    }
  }

  /// Extract error message from response
  String _getErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['detail'] ?? body['message'] ?? 'Unknown error';
    } catch (e) {
      return response.body;
    }
  }

  /// Dispose the client
  void dispose() {
    _client.close();
  }
}

/// Custom API Exception
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
