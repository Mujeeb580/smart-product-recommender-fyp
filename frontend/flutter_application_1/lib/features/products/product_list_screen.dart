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

                    if (products.isEmpty) {
                      return loading_widgets.EmptyStateWidget(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No Products Found',
                        subtitle: 'Try adjusting your search or filters',
                        actionLabel: 'Go Back',
                        onAction: () => Navigator.pop(context),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(AppTheme.paddingMedium),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: AppTheme.paddingMedium,
                        mainAxisSpacing: AppTheme.paddingMedium,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
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
