import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/home/change_password_screen.dart';
import 'package:flutter_application_1/features/home/recommendation_preferences_screen.dart';
import 'package:flutter_application_1/services/theme_provider.dart';

void main() {
  testWidgets('change password form validates empty fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChangePasswordScreen()),
    );

    await tester.tap(find.text('Update Password'));
    await tester.pump();

    expect(find.text('Current password is required'), findsOneWidget);
    expect(find.text('New password is required'), findsOneWidget);
  });

  testWidgets('shopping preferences inputs remain readable in dark mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({'is_dark_mode': true});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const RecommendationPreferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shopping Preferences'), findsOneWidget);
    expect(find.text('Preferred category'), findsOneWidget);
    final input = tester.widget<InputDecorator>(find.byType(InputDecorator).first);
    expect(input.decoration.filled, isTrue);
    expect(input.decoration.fillColor, isNot(Colors.white));
  });
}
