import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

/// State management for products and processor performance
class ProductProvider with ChangeNotifier {
  final ProductService _productService = ProductService();

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  final List<String> tiers = ['Flagship', 'Upper Mid', 'Mid', 'Low'];

  /// Load phones by performance score
  Future<void> loadPhonesByPerformance({
    int limit = 20,
    double? minScore,
    String? tier,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productService.getPhonesByPerformance(
        limit: limit,
        minScore: minScore,
        tier: tier,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load phones by processor tier
  Future<void> loadPhonesByTier(String tier, {int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productService.getPhonesByTier(tier, limit: limit);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load all phones with performance scores
  Future<void> loadAllPhones({int limit = 100}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productService.getPhonesByPerformance(limit: limit);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get detailed score for a phone
  Future<Map<String, dynamic>?> getPhoneScoreDetails(String productId) async {
    try {
      return await _productService.getPhoneScoreDetails(productId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all data
  void clearData() {
    _products = [];
    _error = null;
    notifyListeners();
  }
}
