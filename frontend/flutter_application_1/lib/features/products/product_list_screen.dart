import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title ?? 'Recommended Products'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<ProductModel>>(
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
                _productsFuture = _productService.fetchRecommendedProducts();
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }
}
