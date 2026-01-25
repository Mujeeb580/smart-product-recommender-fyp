import '../models/product_model.dart';

final List<ProductModel> dummyProducts = [
  ProductModel(
    id: '1',
    name: 'iPhone 15 Pro',
    brand: 'Apple',
    price: 299999,
    image: 'assets/images/iphone_15.png',
    similarityScore: 0.95,
    category: 'Smartphones',
    description: 'Latest flagship from Apple with advanced camera system',
    specs: 'A17 Pro | 6GB RAM | 256GB Storage | ProMotion Display',
  ),
  ProductModel(
    id: '2',
    name: 'Samsung Galaxy S24',
    brand: 'Samsung',
    price: 259999,
    image: 'assets/images/galaxy_s24.png',
    similarityScore: 0.92,
    category: 'Smartphones',
    description: 'Premium Android experience with AI features',
    specs: 'Snapdragon 8 Gen 3 | 8GB RAM | 256GB Storage | AMOLED',
  ),
  ProductModel(
    id: '3',
    name: 'Xiaomi 14',
    brand: 'Xiaomi',
    price: 149999,
    image: 'assets/images/xiaomi_14.png',
    similarityScore: 0.88,
    category: 'Smartphones',
    description: 'Affordable flagship with excellent camera quality',
    specs: 'Snapdragon 8 Gen 3 | 12GB RAM | 512GB Storage | 120Hz',
  ),
  ProductModel(
    id: '4',
    name: 'OnePlus 12',
    brand: 'OnePlus',
    price: 169999,
    image: 'assets/images/oneplus_12.png',
    similarityScore: 0.85,
    category: 'Smartphones',
    description: 'Flagship killer with fast charging and smooth performance',
    specs: 'Snapdragon 8 Gen 3 | 12GB RAM | 256GB Storage | 100W Charging',
  ),
  ProductModel(
    id: '5',
    name: 'Realme 12 Pro',
    brand: 'Realme',
    price: 89999,
    image: 'assets/images/realme_12.png',
    similarityScore: 0.80,
    category: 'Smartphones',
    description: 'Budget-friendly flagship with great display',
    specs: 'Snapdragon 7 Gen 3 | 8GB RAM | 256GB Storage | AMOLED',
  ),
  ProductModel(
    id: '6',
    name: 'Google Pixel 8',
    brand: 'Google',
    price: 219999,
    image: 'assets/images/pixel_8.png',
    similarityScore: 0.90,
    category: 'Smartphones',
    description: 'Google\'s finest with amazing computational photography',
    specs: 'Google Tensor G3 | 8GB RAM | 256GB Storage | AI Features',
  ),
  ProductModel(
    id: '7',
    name: 'OPPO A57',
    brand: 'OPPO',
    price: 64999,
    image: 'assets/images/oppo_a57.png',
    similarityScore: 0.75,
    category: 'Smartphones',
    description: 'Entry-level phone with good battery life',
    specs: 'MediaTek Helio G85 | 4GB RAM | 128GB Storage | 5000mAh',
  ),
  ProductModel(
    id: '8',
    name: 'Vivo X100',
    brand: 'Vivo',
    price: 189999,
    image: 'assets/images/vivo_x100.png',
    similarityScore: 0.87,
    category: 'Smartphones',
    description: 'Innovation-focused with advanced camera tech',
    specs: 'MediaTek Dimensity 9300 | 12GB RAM | 512GB Storage | 120Hz',
  ),
  ProductModel(
    id: '9',
    name: 'Infinix Zero 40',
    brand: 'Infinix',
    price: 79999,
    image: 'assets/images/infinix_zero.png',
    similarityScore: 0.78,
    category: 'Smartphones',
    description: 'Young brand with impressive specifications',
    specs: 'MediaTek Dimensity 8200 | 8GB RAM | 256GB Storage | AMOLED',
  ),
  ProductModel(
    id: '10',
    name: 'Poco X6 Pro',
    brand: 'Poco',
    price: 119999,
    image: 'assets/images/poco_x6.png',
    similarityScore: 0.82,
    category: 'Smartphones',
    description: 'Performance-focused gaming phone',
    specs: 'Snapdragon 8 Gen 2 Leading | 12GB RAM | 512GB Storage | 120W',
  ),
];

// Function to get product by ID
ProductModel? getProductById(String id) {
  try {
    return dummyProducts.firstWhere((product) => product.id == id);
  } catch (e) {
    return null;
  }
}

// Function to get recommended products (simulating AI recommendations)
List<ProductModel> getRecommendedProducts({int limit = 5}) {
  return dummyProducts
      .where((p) => p.similarityScore >= 0.80)
      .take(limit)
      .toList();
}
