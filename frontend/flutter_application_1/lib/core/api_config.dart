/// API Configuration for the Smart Product Recommender App
class ApiConfig {
  // Base URL for the backend API
  // For local development, use your machine's IP address or localhost
  // For production, replace with your deployed backend URL
  static const String baseUrl = 'http://localhost:8000';
  
  // Alternative: If running on Android emulator, use 10.0.2.2
  // static const String baseUrl = 'http://10.0.2.2:8000';
  
  // Alternative: If running on physical device, use your machine's IP
  // static const String baseUrl = 'http://192.168.1.100:8000';
  
  // API Endpoints
  static const String authRegister = '$baseUrl/auth/register';
  static const String authLogin = '$baseUrl/auth/login';
  static const String authVerifyToken = '$baseUrl/auth/verify-token';
  
  static const String productsRecommend = '$baseUrl/products/recommend';
  static const String productsSearch = '$baseUrl/products/search';
  static const String productsFilter = '$baseUrl/products/filter';
  
  static const String chatSendMessage = '$baseUrl/chat/send';

  static const String adminOverview = '$baseUrl/admin/overview';
  static const String adminProducts = '$baseUrl/admin/products';
  static const String adminCollections = '$baseUrl/admin/collections';
  
  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
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
