import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/admin/admin_portal_screen.dart';
import 'package:flutter_application_1/models/product_model.dart';
import 'package:flutter_application_1/services/admin_service.dart';

class _FakeAdminService extends AdminService {
  String? lastScrapeMode;

  @override
  Future<Map<String, dynamic>> getOverview() async => {
        'total': 0,
        'products': 0,
        'phones': 0,
        'laptops': 0,
        'users': 0,
      };

  @override
  Future<List<Map<String, dynamic>>> getCollections() async => [
        {'name': 'products', 'count': 0},
        {'name': 'phones', 'count': 0},
        {'name': 'laptops', 'count': 0},
      ];

  @override
  Future<List<ProductModel>> getProducts({
    String collection = 'products',
    String? query,
    int limit = 200,
  }) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getUsers() async => [];

  @override
  Future<Map<String, dynamic>> verifyFirestoreConnection() async =>
      {'ok': true};

  @override
  Future<Map<String, dynamic>> runScraper({
    required String mode,
    int maxPages = 100,
    int maxProducts = 0,
  }) async {
    lastScrapeMode = mode;
    return {'ok': true, 'saved': 1, 'updated': 0};
  }

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('admin portal does not overflow in a short web viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeAdminService();
    await tester.pumpWidget(
      MaterialApp(home: AdminPortalScreen(adminService: service)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No Products'), findsOneWidget);
    final emptyTitle = tester.widget<Text>(find.text('No Products'));
    expect(emptyTitle.style?.color, Colors.white);

    final collectionDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(collectionDropdown.decoration.fillColor, const Color(0xFF123F5B));
    final selectedCollection = tester.widget<Text>(find.text('products'));
    expect(selectedCollection.style?.color, Colors.white);

    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.style?.color, Colors.white);
    expect(searchField.decoration?.fillColor, const Color(0xFF123F5B));

    final scrapePhonesButton =
        find.widgetWithText(ElevatedButton, 'Scrape Phones');
    await tester.ensureVisible(scrapePhonesButton);
    await tester.tap(scrapePhonesButton);
    await tester.pumpAndSettle();
    expect(service.lastScrapeMode, 'phones');
    expect(tester.takeException(), isNull);

    final usersLabels = find.text('Users');
    expect(usersLabels, findsNWidgets(2));
    final usersTab = usersLabels.last;
    await tester.ensureVisible(usersTab);
    await tester.tap(usersTab);
    await tester.pumpAndSettle();
    expect(find.text('No Users'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
