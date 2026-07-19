import 'package:flutter_application_1/services/recommendation_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('voice transcripts require review by default', () async {
    final value = await RecommendationPreferencesService().load();

    expect(value.category, 'any');
    expect(value.budget, isNull);
    expect(value.voiceAutoSend, isFalse);
    expect(value.hasRecommendationDetails, isFalse);
  });

  test('migrates the old auto-send default to review-first once', () async {
    SharedPreferences.setMockInitialValues({'voice_auto_send': true});
    final service = RecommendationPreferencesService();

    expect((await service.load()).voiceAutoSend, isFalse);

    await service.save(const RecommendationPreferences(voiceAutoSend: true));
    expect((await service.load()).voiceAutoSend, isTrue);
  });

  test('saved preferences produce a constrained recommendation query',
      () async {
    final service = RecommendationPreferencesService();
    await service.save(
      const RecommendationPreferences(
        category: 'phones',
        priority: 'battery',
        budget: 50000,
        seniorFriendly: true,
        voiceAutoSend: false,
      ),
    );

    final value = await service.load();
    final query = value.toRecommendationQuery();
    expect(value.voiceAutoSend, isFalse);
    expect(value.summary, contains('Under PKR 50,000'));
    expect(query, contains('phone'));
    expect(query, contains('under PKR 50000'));
    expect(query, contains('battery life'));
    expect(query, contains('elderly'));
  });

  test('reset removes custom recommendation details', () async {
    final service = RecommendationPreferencesService();
    await service.save(
      const RecommendationPreferences(category: 'laptops', budget: 120000),
    );
    await service.reset();

    final value = await service.load();
    expect(value.hasRecommendationDetails, isFalse);
    expect(value.voiceAutoSend, isFalse);
  });
}
