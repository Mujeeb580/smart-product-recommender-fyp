import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/theme_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/loading_widget.dart' as loading_widgets;
import '../../core/theme.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  final List<ProductModel>? initialProducts;
  final String? title;

  const ProductListScreen({super.key, this.initialProducts, this.title});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<ProductModel>> _productsFuture;
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedBrand;
  String? _selectedCategory;
  bool _onlyWithLink = false;
  RangeValues? _priceRange;

  @override
  void initState() {
    super.initState();
    if (widget.initialProducts != null) {
      _productsFuture = Future.value(widget.initialProducts!);
    } else {
      _productsFuture = _productService.fetchRecommendedProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> _applyFilters(List<ProductModel> products) {
    Iterable<ProductModel> filtered = products;

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final haystack = [
          p.name,
          p.brand,
          p.category,
          p.specs ?? '',
          p.processor ?? '',
          p.storage ?? '',
          p.ram ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }

    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      filtered = filtered.where(
          (p) => p.brand.toLowerCase() == _selectedBrand!.toLowerCase());
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where(
          (p) => p.category.toLowerCase() == _selectedCategory!.toLowerCase());
    }

    if (_priceRange != null) {
      filtered = filtered.where(
        (p) =>
            p.price >= _priceRange!.start && p.price <= _priceRange!.end,
      );
    }

    if (_onlyWithLink) {
      filtered = filtered.where((p) => (p.url ?? '').isNotEmpty);
    }

    return filtered.toList();
  }

  void _openFilters(List<ProductModel> products) {
    if (products.isEmpty) return;

    final brands = products
        .map((p) => p.brand.trim())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final categories = products
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final prices = products.map((p) => p.price).toList()..sort();
    final minPrice = prices.first;
    final maxPrice = prices.last;

    RangeValues tempPriceRange = _priceRange ?? RangeValues(minPrice, maxPrice);
    if (tempPriceRange.start < minPrice || tempPriceRange.end > maxPrice) {
      tempPriceRange = RangeValues(minPrice, maxPrice);
    }
    String? tempBrand = _selectedBrand;
    String? tempCategory = _selectedCategory;
    bool tempOnlyWithLink = _onlyWithLink;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _dropdownField(
                        label: 'Brand',
                        value: tempBrand,
                        values: brands,
                        onChanged: (value) => setModalState(() => tempBrand = value),
                      ),
                      const SizedBox(height: 12),
                      _dropdownField(
                        label: 'Category',
                        value: tempCategory,
                        values: categories,
                        onChanged: (value) =>
                            setModalState(() => tempCategory = value),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Price Range: Rs ${tempPriceRange.start.toStringAsFixed(0)} - Rs ${tempPriceRange.end.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      RangeSlider(
                        values: tempPriceRange,
                        min: minPrice,
                        max: maxPrice,
                        divisions: 20,
                        activeColor: const Color(0xFF7C3AED),
                        inactiveColor: Colors.white24,
                        labels: RangeLabels(
                          tempPriceRange.start.toStringAsFixed(0),
                          tempPriceRange.end.toStringAsFixed(0),
                        ),
                        onChanged: (values) =>
                            setModalState(() => tempPriceRange = values),
                      ),
                      SwitchListTile(
                        value: tempOnlyWithLink,
                        onChanged: (value) =>
                            setModalState(() => tempOnlyWithLink = value),
                        activeColor: const Color(0xFF7C3AED),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Only products with purchase link',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedBrand = null;
                                  _selectedCategory = null;
                                  _priceRange = null;
                                  _onlyWithLink = false;
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedBrand = tempBrand;
                                  _selectedCategory = tempCategory;
                                  _priceRange = tempPriceRange;
                                  _onlyWithLink = tempOnlyWithLink;
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: value,
      dropdownColor: const Color(0xFF1A1A2E),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Any')),
        ...values.map((v) => DropdownMenuItem<String?>(value: v, child: Text(v))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final gradientColors = themeProvider.currentGradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title ?? 'Recommended Products',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Products Grid
              Expanded(
                child: FutureBuilder<List<ProductModel>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const loading_widgets.LoadingWidget(
                        message: 'Loading products...',
                      );
                    }

                    if (snapshot.hasError) {
                      return loading_widgets.ErrorWidget(
                        message: 'Failed to load products',
                        onRetry: () => setState(() {
                          _productsFuture =
                              _productService.fetchRecommendedProducts();
                        }),
                      );
                    }

                    final products = snapshot.data ?? [];
                    final filteredProducts = _applyFilters(products);

                    if (products.isEmpty) {
                      return loading_widgets.EmptyStateWidget(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No Products Found',
                        subtitle: 'Try adjusting your search or filters',
                        actionLabel: 'Go Back',
                        onAction: () => Navigator.pop(context),
                      );
                    }

                    if (filteredProducts.isEmpty) {
                      return loading_widgets.EmptyStateWidget(
                        icon: Icons.filter_alt_off,
                        title: 'No Matching Products',
                        subtitle: 'Try changing your filters.',
                        actionLabel: 'Clear Filters',
                        onAction: () {
                          setState(() {
                            _selectedBrand = null;
                            _selectedCategory = null;
                            _priceRange = null;
                            _onlyWithLink = false;
                            _searchController.clear();
                          });
                        },
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Search by name, brand, specs',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.85),
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                child: IconButton(
                                  onPressed: () => _openFilters(products),
                                  icon: const Icon(Icons.filter_alt, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${filteredProducts.length} results',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(AppTheme.paddingMedium),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: AppTheme.paddingMedium,
                              mainAxisSpacing: AppTheme.paddingMedium,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return ProductCard(
                                product: product,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
