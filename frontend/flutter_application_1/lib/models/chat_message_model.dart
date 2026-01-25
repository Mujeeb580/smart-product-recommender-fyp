class ChatMessageModel {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final List<dynamic>?
  recommendedProducts; // Will hold product data from backend

  ChatMessageModel({
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.recommendedProducts,
  });

  // Convert to JSON (for future backend)
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'recommendedProducts': recommendedProducts,
    };
  }

  // Convert from JSON (for future backend)
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      message: json['message'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      recommendedProducts: json['recommendedProducts'] as List<dynamic>?,
    );
  }

  @override
  String toString() =>
      'ChatMessageModel(message: $message, isUser: $isUser, timestamp: $timestamp)';
}
