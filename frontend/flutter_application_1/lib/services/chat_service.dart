import '../models/product_model.dart';
import '../models/chat_message_model.dart';
import '../dummy/dummy_chat.dart';
import '../dummy/dummy_products.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../core/api_config.dart';

class ChatService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  // Flag to use dummy data as fallback
  final bool _useDummyFallback = true;

  /// Sends a message to AI backend and gets recommendations
  Future<Map<String, dynamic>> sendMessage(String userMessage) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.post(
        ApiConfig.chatSendMessage,
        headers: headers,
        body: {
          'message': userMessage,
        },
      );

      String botReply = response['reply'] ?? 'I understand your request.';
      List<ProductModel> products = [];

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        products = productsList
            .map((json) => ProductModel.fromJson(json))
            .toList();
      }

      return {
        'reply': botReply,
        'products': products,
      };
    } catch (e) {
      print('Error sending message: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(
          Duration(milliseconds: 500 + (userMessage.length * 50)),
        );

        String botReply = getAiResponse(userMessage);
        List<ProductModel> recommendedProducts = 
            _getRecommendedProductsForMessage(userMessage);

        return {
          'reply': botReply,
          'products': recommendedProducts,
        };
      }
      
      rethrow;
    }
  }

  /// Helper to select products based on user message intent (fallback)
  List<ProductModel> _getRecommendedProductsForMessage(String userMessage) {
    final message = userMessage.toLowerCase();

    List<ProductModel> products = dummyProducts;

    // Filter based on intent
    if (message.contains('budget') ||
        message.contains('cheap') ||
        message.contains('affordable')) {
      products = dummyProducts.where((p) => p.price < 100000).toList();
    } else if (message.contains('flagship') ||
        message.contains('best') ||
        message.contains('premium')) {
      products = dummyProducts.where((p) => p.price > 200000).toList();
    } else if (message.contains('game') || message.contains('gaming')) {
      products = dummyProducts
          .where((p) => p.category.contains('Smartphone'))
          .toList();
    } else if (message.contains('camera') || message.contains('photo')) {
      products = dummyProducts
          .where((p) => p.specs!.contains('camera'))
          .toList();
      if (products.isEmpty) {
        products = dummyProducts
            .where((p) => p.similarityScore >= 0.87)
            .toList();
      }
    } else {
      // Default: return top-rated products
      products = dummyProducts.where((p) => p.similarityScore >= 0.80).toList();
    }

    // Return top 5 products
    return products.take(5).toList();
  }

  /// Get chat history
  Future<List<ChatMessageModel>> getChatHistory() async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      final response = await _apiService.get(
        '${ApiConfig.baseUrl}/chat/history',
        headers: headers,
      );

      if (response['messages'] != null) {
        final List<dynamic> messagesList = response['messages'];
        return messagesList
            .map((json) => ChatMessageModel.fromJson(json))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('Error fetching chat history: $e');
      
      // Fallback to dummy data
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 300));
        return dummyChatHistory;
      }
      
      return [];
    }
  }

  /// Save chat message
  Future<bool> saveChatMessage(ChatMessageModel message) async {
    try {
      final token = await _authService.getIdToken();
      final headers = token != null 
          ? ApiConfig.authHeaders(token) 
          : ApiConfig.headers;

      await _apiService.post(
        '${ApiConfig.baseUrl}/chat/save',
        headers: headers,
        body: message.toJson(),
      );

      return true;
    } catch (e) {
      print('Error saving message: $e');
      
      // Fallback behavior
      if (_useDummyFallback) {
        await Future.delayed(const Duration(milliseconds: 200));
        dummyChatHistory.add(message);
        return true;
      }
      
      return false;
    }
  }
}
