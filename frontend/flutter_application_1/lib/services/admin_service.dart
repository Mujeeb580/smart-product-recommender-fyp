import '../core/api_config.dart';
import '../models/product_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AdminService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getIdToken();
    return token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;
  }

  Future<Map<String, dynamic>> getOverview() async {
    final headers = await _headers();
    return _apiService.get(ApiConfig.adminOverview, headers: headers);
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

  Future<Map<String, dynamic>> runScraper({required String mode}) async {
    final headers = await _headers();
    return _apiService.post(
      ApiConfig.adminScrapeRun,
      headers: headers,
      body: {'mode': mode},
    );
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
}
