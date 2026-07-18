import 'package:shared_preferences/shared_preferences.dart';

class RecommendationPreferences {
  final String category;
  final String priority;
  final int? budget;
  final bool seniorFriendly;
  final bool voiceAutoSend;

  const RecommendationPreferences({
    this.category = 'any',
    this.priority = 'balanced',
    this.budget,
    this.seniorFriendly = false,
    this.voiceAutoSend = true,
  });

  bool get hasRecommendationDetails =>
      category != 'any' ||
      priority != 'balanced' ||
      budget != null ||
      seniorFriendly;

  String get summary {
    final parts = <String>[
      category == 'any' ? 'Phones or laptops' : categoryLabel(category),
      priorityLabel(priority),
      if (budget != null) 'Under PKR ${_formatNumber(budget!)}',
      if (seniorFriendly) 'Easy to use',
    ];
    return parts.join(' • ');
  }

  String toRecommendationQuery() {
    final product = switch (category) {
      'phones' => 'phone',
      'laptops' => 'laptop',
      _ => 'phone or laptop',
    };
    final parts = <String>['Recommend the best $product for me'];
    if (budget != null) parts.add('under PKR $budget');
    if (priority != 'balanced') {
      parts
          .add('with ${priorityLabel(priority).toLowerCase()} as the priority');
    } else {
      parts.add('with balanced everyday performance and value');
    }
    if (seniorFriendly) {
      parts.add(
          'that is easy for an elderly person to use for calling and social media');
    }
    return '${parts.join(', ')}.';
  }

  static String categoryLabel(String value) => switch (value) {
        'phones' => 'Phones',
        'laptops' => 'Laptops',
        _ => 'Any category',
      };

  static String priorityLabel(String value) => switch (value) {
        'battery' => 'Battery life',
        'camera' => 'Camera quality',
        'performance' => 'Performance',
        'value' => 'Best value',
        _ => 'Balanced use',
      };

  static String _formatNumber(int value) {
    final digits = value.toString();
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) result.write(',');
      result.write(digits[i]);
    }
    return result.toString();
  }
}

class RecommendationPreferencesService {
  static const _categoryKey = 'recommendation_category';
  static const _priorityKey = 'recommendation_priority';
  static const _budgetKey = 'recommendation_budget';
  static const _seniorKey = 'recommendation_senior_friendly';
  static const _voiceAutoSendKey = 'voice_auto_send';

  Future<RecommendationPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    final budget = preferences.getInt(_budgetKey);
    return RecommendationPreferences(
      category: preferences.getString(_categoryKey) ?? 'any',
      priority: preferences.getString(_priorityKey) ?? 'balanced',
      budget: budget != null && budget > 0 ? budget : null,
      seniorFriendly: preferences.getBool(_seniorKey) ?? false,
      voiceAutoSend: preferences.getBool(_voiceAutoSendKey) ?? true,
    );
  }

  Future<void> save(RecommendationPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_categoryKey, value.category),
      preferences.setString(_priorityKey, value.priority),
      preferences.setBool(_seniorKey, value.seniorFriendly),
      preferences.setBool(_voiceAutoSendKey, value.voiceAutoSend),
      if (value.budget != null)
        preferences.setInt(_budgetKey, value.budget!)
      else
        preferences.remove(_budgetKey),
    ]);
  }

  Future<void> reset() => save(const RecommendationPreferences());
}
