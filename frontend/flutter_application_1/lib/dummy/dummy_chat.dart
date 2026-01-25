import '../models/chat_message_model.dart';

final List<ChatMessageModel> dummyChatHistory = [
  ChatMessageModel(
    message:
        'Hello! I\'m your AI product assistant. Tell me what you\'re looking for!',
    isUser: false,
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
  ),
];

// AI responses for different user intents
const Map<String, String> aiResponses = {
  'budget':
      'Based on your budget, I recommend checking out these phones. They offer great value for money and have excellent features!',
  'flagship':
      'Looking for the best of the best? These flagship phones are packed with the latest technology and premium features.',
  'gaming':
      'For gaming enthusiasts! These phones have powerful processors and high refresh rates perfect for an excellent gaming experience.',
  'camera':
      'If photography is your passion, these phones feature advanced camera systems with AI enhancements.',
  'battery':
      'Need long battery life? These phones come with massive batteries and efficient processors.',
  'performance':
      'For power users! These phones have the fastest processors and maximum RAM for multitasking.',
  'brand': 'Great choice! Here are some excellent options from that brand.',
  'default':
      'These recommendations are based on your preferences. Check them out!',
};

// Function to get AI response based on intent
String getAiResponse(String userMessage) {
  final message = userMessage.toLowerCase();

  if (message.contains('budget') ||
      message.contains('cheap') ||
      message.contains('affordable')) {
    return aiResponses['budget']!;
  } else if (message.contains('flagship') ||
      message.contains('best') ||
      message.contains('premium')) {
    return aiResponses['flagship']!;
  } else if (message.contains('game') ||
      message.contains('gaming') ||
      message.contains('fps')) {
    return aiResponses['gaming']!;
  } else if (message.contains('camera') ||
      message.contains('photo') ||
      message.contains('video')) {
    return aiResponses['camera']!;
  } else if (message.contains('battery') ||
      message.contains('charge') ||
      message.contains('endurance')) {
    return aiResponses['battery']!;
  } else if (message.contains('performance') ||
      message.contains('fast') ||
      message.contains('speed')) {
    return aiResponses['performance']!;
  } else if (message.contains('apple') ||
      message.contains('iphone') ||
      message.contains('samsung') ||
      message.contains('xiaomi') ||
      message.contains('oppo') ||
      message.contains('vivo')) {
    return aiResponses['brand']!;
  } else {
    return aiResponses['default']!;
  }
}

// Sample conversation starters
const List<String> conversationStarters = [
  'I want a budget smartphone',
  'Show me the latest flagship phones',
  'Best phone for gaming',
  'Phones with great cameras',
  'Need long battery life',
];
