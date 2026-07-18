import 'package:flutter_application_1/core/price_formatter.dart';
import 'package:flutter_application_1/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

ProductModel productWithPrice(dynamic price) => ProductModel.fromJson({
      'id': 'test-product',
      'name': 'Test Product',
      'brand': 'Test',
      'category': 'Laptops',
      'image': '',
      'price': price,
    });

void main() {
  test('parses numeric and common Pakistani price strings', () {
    expect(productWithPrice(122999).price, 122999);
    expect(productWithPrice('PKR 119,999').price, 119999);
    expect(productWithPrice('Rs. 122,999').price, 122999);
    expect(productWithPrice('₨ 99,500.50').price, 99500.50);
  });

  test('invalid price remains safely zero', () {
    expect(productWithPrice('Price unavailable').price, 0);
    expect(productWithPrice(null).price, 0);
  });

  test('formats prices consistently as PKR with separators', () {
    expect(formatPkr(0), 'PKR 0');
    expect(formatPkr(119999), 'PKR 119,999');
    expect(formatPkr(992999), 'PKR 992,999');
  });
}
