import '../models/product_model.dart';
import '../dummy/dummy_products.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../core/api_config.dart';

class ProductService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  // Flag to use dummy data as fallback
  final bool _useDummyFallback = true;

  /// Fetch all recommended products from backend
  Future<List<ProductModel>> fetchRecommendedProducts({String? query}) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        ApiConfig.productsRecommend,
        headers: headers,
        queryParams: query != null ? {'query': query} : null,
      );

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        return productsList
            .map((json) => ProductModel.fromJson(json))
            .toList();
      }
      
      throw Exception('No products in response');
    } catch (e) {
      print('Error fetching products: $e');
      
      // Fallback to dummy data if API fails
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 800));
        final products = List<ProductModel>.from(dummyProducts);
        products.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
        return products;
      }
      
      rethrow;
    }
  }

  /// Fetch product details by ID
  Future<ProductModel?> fetchProductDetails(String id) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        '${ApiConfig.baseUrl}/products/$id',
        headers: headers,
      );

      if (response['product'] != null) {
        return ProductModel.fromJson(response['product']);
      }
      
      throw Exception('Product not found');
    } catch (e) {
      print('Error fetching product details: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 500));
        return getProductById(id);
      }
      
      rethrow;
    }
  }

  /// Search products by query
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        ApiConfig.productsSearch,
        headers: headers,
        queryParams: {'q': query},
      );

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        return productsList
            .map((json) => ProductModel.fromJson(json))
            .toList();
      }
      
      throw Exception('No products in response');
    } catch (e) {
      print('Error searching products: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 600));
        final q = query.toLowerCase();
        return dummyProducts
            .where(
              (p) =>
                  p.name.toLowerCase().contains(q) ||
                  p.brand.toLowerCase().contains(q) ||
                  p.category.toLowerCase().contains(q),
            )
            .toList();
      }
      
      rethrow;
    }
  }

  /// Filter products by category
  Future<List<ProductModel>> filterByCategory(String category) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        ApiConfig.productsFilter,
        headers: headers,
        queryParams: {'category': category},
      );

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        return productsList
            .map((json) => ProductModel.fromJson(json))
            .toList();
      }
      
      throw Exception('No products in response');
    } catch (e) {
      print('Error filtering by category: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 500));
        return dummyProducts
            .where((p) => p.category.toLowerCase() == category.toLowerCase())
            .toList();
      }
      
      rethrow;
    }
  }

  /// Filter products by price range
  Future<List<ProductModel>> filterByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        ApiConfig.productsFilter,
        headers: headers,
        queryParams: {
          'min_price': minPrice.toString(),
          'max_price': maxPrice.toString(),
        },
      );

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        return productsList
            .map((json) => ProductModel.fromJson(json))
            .toList();
      }
      
      throw Exception('No products in response');
    } catch (e) {
      print('Error filtering by price: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 500));
        return dummyProducts
            .where((p) => p.price >= minPrice && p.price <= maxPrice)
            .toList();
      }
      
      rethrow;
    }
  }

  /// Get trending/popular products
  Future<List<ProductModel>> getTrendingProducts() async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        '${ApiConfig.baseUrl}/products/trending',
        headers: headers,
      );

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        return productsList
            .map((json) => ProductModel.fromJson(json))
            .toList();
      }
      
      throw Exception('No products in response');
    } catch (e) {
      print('Error fetching trending products: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 600));
        final products = List<ProductModel>.from(dummyProducts);
        products.shuffle();
        return products.take(5).toList();
      }
      
      rethrow;
    }
  }
}
