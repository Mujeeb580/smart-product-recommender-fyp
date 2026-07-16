import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../widgets/loading_widget.dart' as loading_widgets;
import '../../widgets/product_card.dart';
import '../products/product_detail_screen.dart';

class LaptopsScreen extends StatefulWidget {
  const LaptopsScreen({super.key});

  @override
  State<LaptopsScreen> createState() => _LaptopsScreenState();
}

class _LaptopsScreenState extends State<LaptopsScreen> {
  final ProductService _productService = ProductService();
  late Future<List<ProductModel>> _productsFuture;
  bool _isListView = true;

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
  }

  Future<List<ProductModel>> _loadProducts() {
    return _productService.fetchCollectionProducts(
        collection: 'laptops', limit: 40);
  }

  void _refresh() {
    setState(() {
      _productsFuture = _loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF0F766E), Color(0xFF0E7490), Color(0xFF38BDF8)];

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const _GlassIconButton(
                          icon: Icons.arrow_back_ios_new),
                    ),
                    Text(
                      'Laptops',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isListView = true),
                          child: _GlassIconButton(
                            icon: Icons.view_list,
                            isActive: _isListView,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _isListView = false),
                          child: _GlassIconButton(
                            icon: Icons.grid_view,
                            isActive: !_isListView,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ProductModel>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const loading_widgets.LoadingWidget(
                        message: 'Loading laptops from Firestore...',
                      );
                    }

                    if (snapshot.hasError) {
                      return loading_widgets.ErrorWidget(
                        message: 'Failed to load laptops',
                        onRetry: _refresh,
                      );
                    }

                    final products = snapshot.data ?? [];
                    if (products.isEmpty) {
                      return const loading_widgets.EmptyStateWidget(
                        icon: Icons.laptop_mac,
                        title: 'No Laptops Found',
                        subtitle: 'Your Firestore laptops collection is empty.',
                      );
                    }

                    return _isListView
                        ? ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CompactProductTile(
                                  product: product,
                                  icon: Icons.laptop_mac,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProductDetailScreen(
                                                product: product),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ProductCard(
                                product: product,
                                showSimilarity: false,
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

class _CompactProductTile extends StatelessWidget {
  final ProductModel product;
  final IconData icon;
  final VoidCallback onTap;

  const _CompactProductTile(
      {required this.product, required this.icon, required this.onTap});

  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: Colors.white.withOpacity(0.18),
                    child: _isNetworkImage(product.image)
                        ? Image.network(
                            product.image,
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.prefer,
                            errorBuilder: (_, __, ___) =>
                                Icon(icon, color: Colors.white, size: 36),
                          )
                        : Icon(icon, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.brand,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.specs ?? product.category,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rs ${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;

  const _GlassIconButton({required this.icon, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF0E7490).withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0E7490).withOpacity(0.8)
                  : Colors.white.withOpacity(0.3),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
