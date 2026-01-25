class ProductModel {
  final String id;
  final String name;
  final String brand;
  final double price;
  final String image; // local asset path
  final double similarityScore; // 0.0 to 1.0
  final String category;
  final String? description;
  final String? specs;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.image,
    required this.similarityScore,
    required this.category,
    this.description,
    this.specs,
  });

  // Convert to JSON (for future backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'price': price,
      'image': image,
      'similarityScore': similarityScore,
      'category': category,
      'description': description,
      'specs': specs,
    };
  }

  // Convert from JSON (for future backend)
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String,
      similarityScore: (json['similarityScore'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String?,
      specs: json['specs'] as String?,
    );
  }

  // Copy with method for easy modifications
  ProductModel copyWith({
    String? id,
    String? name,
    String? brand,
    double? price,
    String? image,
    double? similarityScore,
    String? category,
    String? description,
    String? specs,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      image: image ?? this.image,
      similarityScore: similarityScore ?? this.similarityScore,
      category: category ?? this.category,
      description: description ?? this.description,
      specs: specs ?? this.specs,
    );
  }

  @override
  String toString() =>
      'ProductModel(id: $id, name: $name, brand: $brand, price: $price)';
}
