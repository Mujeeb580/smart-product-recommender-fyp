import 'package:flutter/foundation.dart';

/// API Configuration for the Smart Product Recommender App
class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Android emulator cannot reach host localhost directly.
  // Desktop and web can use localhost, while Android uses 10.0.2.2.
  static String get baseUrl {
    final configuredUrl = _configuredBaseUrl.trim();
    if (configuredUrl.isNotEmpty) {
      // Endpoint getters add their own leading slash.
      return configuredUrl.endsWith('/')
          ? configuredUrl.substring(0, configuredUrl.length - 1)
          : configuredUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  // API Endpoints
  static String get authRegister => '$baseUrl/auth/register';
  static String get authLogin => '$baseUrl/auth/login';
  static String get authVerifyToken => '$baseUrl/auth/verify-token';

  static String get productsRecommend => '$baseUrl/products/recommend';
  static String get productsSearch => '$baseUrl/products/search';
  static String get productsFilter => '$baseUrl/products/filter';
  static String get productsTrending => '$baseUrl/products/trending';

  // Processor Performance Scoring Endpoints
  static String get phonesPerformance => '$baseUrl/products/phones/performance';
  static String get phonesByTier => '$baseUrl/products/phones/by-tier';
  static String get phoneScoreDetails =>
      '$baseUrl/products/phones/score-details';

  static String get chatSendMessage => '$baseUrl/chat/send-message';

  static String get adminOverview => '$baseUrl/admin/overview';
  static String get adminLogin => '$baseUrl/admin/login';
  static String get adminLogout => '$baseUrl/admin/logout';
  static String get adminSession => '$baseUrl/admin/session';
  static String get adminProducts => '$baseUrl/admin/products';
  static String get adminUsers => '$baseUrl/admin/users';
  static String get adminCollections => '$baseUrl/admin/collections';
  static String get adminProductCreate => '$baseUrl/admin/products';
  static String get adminProductUpdate => '$baseUrl/admin/products';
  static String get adminProductDelete => '$baseUrl/admin/products';
  static String get adminScrapeRun => '$baseUrl/admin/scrape/run';
  static String get adminScrapeStatus => '$baseUrl/admin/scrape/status';
  static String get adminScrapeVerifyFirestore =>
      '$baseUrl/admin/scrape/verify-firestore';

  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Request headers
  static Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Get auth headers with token
  static Map<String, String> authHeaders(String token) {
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }
}
