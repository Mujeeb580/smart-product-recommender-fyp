class ProductModel {
  final String id;
  final String name;
  final String brand;
  final double price;
  final String image;
  final double similarityScore; // 0.0 to 1.0
  final String category;
  final String? description;
  final String? specs;
  final String? url;
  final String? source;
  final String? collection;
  final String? productId;
  final String? scrapedAt;
  final String? ram;
  final String? storage;
  final String? processor;
  final String? gpu;
  final String? battery;
  final String? camera;
  // Processor performance scoring fields
  final double? processorScore;
  final String? processorTier;
  final String? normalizedProcessor;
  final PerformanceBreakdown? performanceBreakdown;

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
    this.url,
    this.source,
    this.collection,
    this.productId,
    this.scrapedAt,
    this.ram,
    this.storage,
    this.processor,
    this.gpu,
    this.battery,
    this.camera,
    this.processorScore,
    this.processorTier,
    this.normalizedProcessor,
    this.performanceBreakdown,
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
      'url': url,
      'source': source,
      'collection': collection,
      'product_id': productId,
      'scraped_at': scrapedAt,
      'ram': ram,
      'storage': storage,
      'processor': processor,
      'gpu': gpu,
      'battery': battery,
      'camera': camera,
      'processor_score': processorScore,
      'processor_tier': processorTier,
      'normalized_processor': normalizedProcessor,
      'performance_breakdown': performanceBreakdown?.toJson(),
    };
  }

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll('Rs', '').replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }

  // Convert from JSON for backend data.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['product_id'] ?? '';
    final rawName = json['name'] ?? 'Unknown Product';
    final rawBrand = json['brand'] ?? 'Unknown';
    final rawCategory = json['category'] ?? json['collection'] ?? 'Product';
    final rawImage = (json['image'] ?? json['image_url'] ?? '').toString();
    final rawScore = json['similarityScore'] ?? json['similarity_score'] ?? 0.0;

    return ProductModel(
      id: rawId.toString(),
      name: rawName.toString(),
      brand: rawBrand.toString(),
      price: _toDouble(json['price']),
      image: rawImage,
      similarityScore: _toDouble(rawScore),
      category: rawCategory.toString(),
      description: json['description']?.toString(),
      specs: json['specs']?.toString(),
      url: json['url']?.toString(),
      source: json['source']?.toString(),
      collection: json['collection']?.toString(),
      productId: json['product_id']?.toString(),
      scrapedAt: json['scraped_at']?.toString(),
      ram: json['ram']?.toString(),
      storage: json['storage']?.toString(),
      processor: json['processor']?.toString(),
      gpu: json['gpu']?.toString(),
      battery: json['battery']?.toString(),
      camera: json['camera']?.toString(),
      processorScore: _toDouble(json['processor_score']),
      processorTier: json['processor_tier']?.toString(),
      normalizedProcessor: json['normalized_processor']?.toString(),
      performanceBreakdown: json['performance_breakdown'] != null
          ? PerformanceBreakdown.fromJson(json['performance_breakdown'])
          : null,
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
    String? url,
    String? source,
    String? collection,
    String? productId,
    String? scrapedAt,
    String? ram,
    String? storage,
    String? processor,
    String? gpu,
    String? battery,
    String? camera,
    double? processorScore,
    String? processorTier,
    String? normalizedProcessor,
    PerformanceBreakdown? performanceBreakdown,
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
      url: url ?? this.url,
      source: source ?? this.source,
      collection: collection ?? this.collection,
      productId: productId ?? this.productId,
      scrapedAt: scrapedAt ?? this.scrapedAt,
      ram: ram ?? this.ram,
      storage: storage ?? this.storage,
      processor: processor ?? this.processor,
      gpu: gpu ?? this.gpu,
      battery: battery ?? this.battery,
      camera: camera ?? this.camera,
      processorScore: processorScore ?? this.processorScore,
      processorTier: processorTier ?? this.processorTier,
      normalizedProcessor: normalizedProcessor ?? this.normalizedProcessor,
      performanceBreakdown: performanceBreakdown ?? this.performanceBreakdown,
    );
  }

  @override
  String toString() =>
      'ProductModel(id: $id, name: $name, brand: $brand, price: $price, processorScore: $processorScore)';
}

/// Performance breakdown for processor scoring
class PerformanceBreakdown {
  final double? baseChipsetScore;
  final double? ramScore;
  final double? batteryScore;
  final double? recencyScore;

  PerformanceBreakdown({
    this.baseChipsetScore,
    this.ramScore,
    this.batteryScore,
    this.recencyScore,
  });

  factory PerformanceBreakdown.fromJson(Map<String, dynamic> json) {
    return PerformanceBreakdown(
      baseChipsetScore: ProductModel._toDouble(json['base_chipset_score']),
      ramScore: ProductModel._toDouble(json['ram_score']),
      batteryScore: ProductModel._toDouble(json['battery_score']),
      recencyScore: ProductModel._toDouble(json['recency_score']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_chipset_score': baseChipsetScore,
      'ram_score': ramScore,
      'battery_score': batteryScore,
      'recency_score': recencyScore,
    };
  }

  @override
  String toString() =>
      'PerformanceBreakdown(chipset: $baseChipsetScore, ram: $ramScore, battery: $batteryScore, recency: $recencyScore)';
}
