import '../core/api_config.dart';
import '../models/product_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AdminService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getOverview() async {
    final token = await _authService.getIdToken();
    final headers = token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;
    return _apiService.get(ApiConfig.adminOverview, headers: headers);
  }

  Future<List<Map<String, dynamic>>> getCollections() async {
    final token = await _authService.getIdToken();
    final headers = token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;
    final response = await _apiService.get(ApiConfig.adminCollections, headers: headers);

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
    final token = await _authService.getIdToken();
    final headers = token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;

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
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return [];
  }
}
