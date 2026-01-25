import '../models/product_model.dart';
import '../dummy/dummy_products.dart';

class ProductService {
  // Fetch all recommended products
  Future<List<ProductModel>> fetchRecommendedProducts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Return products sorted by similarity score
    final products = List<ProductModel>.from(dummyProducts);
    products.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return products;
  }

  // Fetch product details by ID
  Future<ProductModel?> fetchProductDetails(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return getProductById(id);
  }

  // Search products by name or brand
  Future<List<ProductModel>> searchProducts(String query) async {
    // Simulate network delay
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

  // Filter products by category
  Future<List<ProductModel>> filterByCategory(String category) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return dummyProducts
        .where((p) => p.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  // Filter products by price range
  Future<List<ProductModel>> filterByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return dummyProducts
        .where((p) => p.price >= minPrice && p.price <= maxPrice)
        .toList();
  }

  // Get trending/popular products
  Future<List<ProductModel>> getTrendingProducts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    final products = List<ProductModel>.from(dummyProducts);
    products.shuffle();
    return products.take(5).toList();
  }
}
