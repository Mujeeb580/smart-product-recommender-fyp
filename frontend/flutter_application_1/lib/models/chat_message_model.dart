class ChatMessageModel {
  final String id;
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final List<dynamic>? recommendedProducts;
  final MessageType type;
  final Map<String, dynamic>? metadata;

  ChatMessageModel({
    String? id,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.recommendedProducts,
    this.type = MessageType.text,
    this.metadata,
  }) : id = id ?? _generateId();

  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  ChatMessageModel copyWith({
    String? id,
    String? message,
    bool? isUser,
    DateTime? timestamp,
    List<dynamic>? recommendedProducts,
    MessageType? type,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      message: message ?? this.message,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      recommendedProducts: recommendedProducts ?? this.recommendedProducts,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to JSON (for future backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'recommendedProducts': recommendedProducts,
      'type': type.name,
      'metadata': metadata,
    };
  }

  // Convert from JSON (for future backend)
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? _generateId(),
      message: json['message'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      recommendedProducts: json['recommendedProducts'] as List<dynamic>?,
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'ChatMessageModel(id: $id, message: $message, isUser: $isUser, timestamp: $timestamp, type: $type)';
}

enum MessageType {
  text,
  productRecommendation,
  systemMessage,
  quickReply,
  error,
}
