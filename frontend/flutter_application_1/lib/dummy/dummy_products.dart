import '../models/product_model.dart';

final List<ProductModel> dummyProducts = [
  ProductModel(
    id: '1',
    name: 'iPhone 15 Pro',
    brand: 'Apple',
    price: 299999,
    image:
        'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1592286927505-b21084d350fd?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1598965402089-897ce52e8355?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1574944985070-8f3ebc6b79d2?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1601784551446-20c9e07cdbdb?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1585060544812-6b45742d762f?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
    image:
        'https://images.unsplash.com/photo-1563203369-26f2e4a5ccf7?w=500&h=600&fit=crop&crop=center&auto=format&q=80',
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
