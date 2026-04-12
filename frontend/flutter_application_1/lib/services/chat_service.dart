import '../models/product_model.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../core/api_config.dart';

class ChatService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  static String? _sessionId;

  String _getSessionId() {
    _sessionId ??=
        'session_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
    return _sessionId!;
  }

  /// Sends a message to AI backend and gets recommendations
  Future<Map<String, dynamic>> sendMessage(String userMessage) async {
    try {
      final token = await _authService.getIdToken();
      final headers =
          token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;

      final response = await _apiService.post(
        ApiConfig.chatSendMessage,
        headers: headers,
        body: {
          'message': userMessage,
          'session_id': _getSessionId(),
        },
      );

      String botReply = response['reply'] ?? 'I understand your request.';
      List<ProductModel> products = [];

      if (response['products'] != null) {
        final List<dynamic> productsList = response['products'];
        products =
            productsList.map((json) => ProductModel.fromJson(json)).toList();
      }

      return {
        'reply': botReply,
        'products': products,
      };
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  /// Get chat history
  Future<List<ChatMessageModel>> getChatHistory() async {
    try {
      final token = await _authService.getIdToken();
      final headers =
          token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;

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
      rethrow;
    }
  }

  /// Save chat message
  Future<bool> saveChatMessage(ChatMessageModel message) async {
    try {
      final token = await _authService.getIdToken();
      final headers =
          token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;

      await _apiService.post(
        '${ApiConfig.baseUrl}/chat/save',
        headers: headers,
        body: message.toJson(),
      );

      return true;
    } catch (e) {
      print('Error saving message: $e');
      rethrow;
    }
  }
}
