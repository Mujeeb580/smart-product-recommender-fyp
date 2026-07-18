import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product_model.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../core/api_config.dart';

class ChatService {
  final ApiService _apiService = ApiService();
  final Future<String?> Function() _tokenProvider;
  final http.Client _httpClient;
  static String? _sessionId;

  ChatService({
    Future<String?> Function()? tokenProvider,
    http.Client? httpClient,
  })  : _tokenProvider = tokenProvider ?? AuthService().getIdToken,
        _httpClient = httpClient ?? http.Client();

  String _getSessionId() {
    _sessionId ??=
        'session_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
    return _sessionId!;
  }

  /// Starts a fresh recommendation conversation and clears backend context.
  void startNewSession() {
    _sessionId =
        'session_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
  }

  /// Sends a message to AI backend and gets recommendations
  Future<Map<String, dynamic>> sendMessage(String userMessage,
      {ProductModel? product}) async {
    try {
      final token = await _tokenProvider();
      final headers =
          token != null ? ApiConfig.authHeaders(token) : ApiConfig.headers;

      final body = {
        'message': userMessage,
        'session_id': _getSessionId(),
      };
      if (product != null) {
        body['product_id'] = product.productId?.isNotEmpty == true
            ? product.productId!
            : (product.id.isNotEmpty ? product.id : product.name);
      }

      final response = await _apiService.post(
        ApiConfig.chatSendMessage,
        headers: headers,
        body: body,
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

  /// Uploads a voice recording to the backend and returns its transcript.
  Future<String> transcribeAudio(String audioPath) async {
    try {
      final token = await _tokenProvider();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.chatTranscribe),
      );
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));

      final streamedResponse =
          await _httpClient.send(request).timeout(ApiConfig.receiveTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      }
      if (response.statusCode != 200) {
        throw ApiException(
          body['detail']?.toString() ?? 'Voice transcription failed.',
        );
      }

      final transcript = body['text']?.toString().trim() ?? '';
      if (transcript.isEmpty) {
        throw ApiException('No speech was detected. Please try again.');
      }
      return transcript;
    } on TimeoutException {
      throw ApiException('Voice transcription timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not transcribe the recording: $e');
    }
  }

  /// Get chat history
  Future<List<ChatMessageModel>> getChatHistory() async {
    try {
      final token = await _tokenProvider();
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
      final token = await _tokenProvider();
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
