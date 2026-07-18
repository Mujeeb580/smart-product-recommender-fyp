import '../core/api_config.dart';
import '../models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AdminService {
  static const String adminUsername = 'admin@fyndo.com';
  static const String _adminTokenKey = 'admin_session_token';

  final ApiService _apiService = ApiService();

  Future<void> login(String username, String password) async {
    final response = await _apiService.post(
      ApiConfig.adminLogin,
      body: {'username': username.trim(), 'password': password},
    );
    final token = response['token']?.toString() ?? '';
    if (token.isEmpty) throw Exception('Admin login did not return a session.');

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_adminTokenKey, token);
  }

  Future<bool> hasStoredSession() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getString(_adminTokenKey) ?? '').isNotEmpty;
  }

  Future<bool> hasValidSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_adminTokenKey);
    if (token == null || token.isEmpty) return false;

    try {
      await _apiService.get(
        ApiConfig.adminSession,
        headers: ApiConfig.authHeaders(token),
      );
      return true;
    } catch (_) {
      await preferences.remove(_adminTokenKey);
      return false;
    }
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_adminTokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        await _apiService.post(
          ApiConfig.adminLogout,
          headers: ApiConfig.authHeaders(token),
        );
      } catch (_) {
        // Always clear a local admin session, even if the backend restarted.
      }
    }
    await preferences.remove(_adminTokenKey);
  }

  Future<Map<String, String>> _headers() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_adminTokenKey);
    if (token == null || token.isEmpty) {
      throw Exception('Admin session expired. Please sign in again.');
    }
    return ApiConfig.authHeaders(token);
  }

  Future<Map<String, dynamic>> getOverview() async {
    final headers = await _headers();
    return _apiService.get(ApiConfig.adminOverview, headers: headers);
  }

  Future<Map<String, dynamic>> getHealth() async {
    final headers = await _headers();
    return _apiService.get(ApiConfig.adminHealth, headers: headers);
  }

  Future<List<Map<String, dynamic>>> getCollections() async {
    final headers = await _headers();
    final response =
        await _apiService.get(ApiConfig.adminCollections, headers: headers);

    final rows = response['collections'];
    if (rows is List) {
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<ProductModel>> getProducts({
    String collection = 'products',
    String? query,
    int limit = 200,
  }) async {
    final headers = await _headers();

    final response = await _apiService.get(
      ApiConfig.adminProducts,
      headers: headers,
      queryParams: {
        'collection': collection,
        'limit': limit,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    final rows = response['products'];
    if (rows is List) {
      return rows
          .map(
              (e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> verifyFirestoreConnection() async {
    final headers = await _headers();
    return _apiService.get(ApiConfig.adminScrapeVerifyFirestore,
        headers: headers);
  }

  Future<Map<String, dynamic>> runScraper({
    required String mode,
    int maxPages = 100,
    int maxProducts = 0,
  }) async {
    final headers = await _headers();
    final started = await _apiService.post(
      ApiConfig.adminScrapeRun,
      headers: headers,
      body: {
        'mode': mode,
        'max_pages': maxPages,
        'max_products': maxProducts,
      },
    );
    final jobId = started['job_id']?.toString() ?? '';
    if (jobId.isEmpty) {
      throw Exception('Backend did not return a scraper job ID.');
    }

    final deadline = DateTime.now().add(const Duration(hours: 3));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final job = await _apiService.get(
        '${ApiConfig.adminScrapeStatus}/$jobId',
        headers: headers,
      );
      final status = job['status']?.toString();
      if (status == 'completed') {
        return Map<String, dynamic>.from(job['result'] as Map);
      }
      if (status == 'failed') {
        throw Exception(job['error'] ?? 'Scraper job failed.');
      }
    }
    throw Exception('Scraper job exceeded the three-hour safety limit.');
  }

  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    final headers = await _headers();
    final response = await _apiService.post(
      ApiConfig.adminProductCreate,
      headers: headers,
      body: data,
    );
    final product = response['product'];
    return ProductModel.fromJson(Map<String, dynamic>.from(product as Map));
  }

  Future<ProductModel> updateProduct(
      String collection, String productId, Map<String, dynamic> data) async {
    final headers = await _headers();
    final url = '${ApiConfig.adminProductUpdate}/$collection/$productId';
    final response = await _apiService.put(
      url,
      headers: headers,
      body: data,
    );
    final product = response['product'];
    return ProductModel.fromJson(Map<String, dynamic>.from(product as Map));
  }

  Future<void> deleteProduct(String? collection, String productId) async {
    final headers = await _headers();
    final col = collection ?? 'products';
    final url = '${ApiConfig.adminProductDelete}/$col/$productId';
    await _apiService.delete(
      url,
      headers: headers,
    );
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final headers = await _headers();
    final response = await _apiService.get(
      ApiConfig.adminUsers,
      headers: headers,
      queryParams: {'limit': 1000},
    );
    final rows = response['users'];
    if (rows is! List) return [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> deleteUser(String uid) async {
    final headers = await _headers();
    await _apiService.delete(
      '${ApiConfig.adminUsers}/$uid',
      headers: headers,
    );
  }
}
