import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/home/change_password_screen.dart';

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
}
