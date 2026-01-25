import '../models/product_model.dart';
import '../models/chat_message_model.dart';
import '../dummy/dummy_chat.dart';
import '../dummy/dummy_products.dart';

class ChatService {
  // Simulates sending a message to AI backend and getting recommendations
  Future<Map<String, dynamic>> sendMessage(String userMessage) async {
    // Simulate network delay (0.5-2 seconds)
    await Future.delayed(
      Duration(milliseconds: 500 + (userMessage.length * 50)),
    );

    // Get AI response based on message
    String botReply = getAiResponse(userMessage);

    // Get recommended products (in real backend, this would be personalized)
    List<ProductModel> recommendedProducts = _getRecommendedProductsForMessage(
      userMessage,
    );

    return {'reply': botReply, 'products': recommendedProducts};
  }

  // Helper to select products based on user message intent
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

  // Get chat history (for future implementation)
  Future<List<ChatMessageModel>> getChatHistory() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return dummyChatHistory;
  }

  // Save chat message (for future implementation)
  Future<bool> saveChatMessage(ChatMessageModel message) async {
    await Future.delayed(const Duration(milliseconds: 200));
    dummyChatHistory.add(message);
    return true;
  }
}
