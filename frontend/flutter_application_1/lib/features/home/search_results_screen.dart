import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../products/product_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  final ProductService _productService = ProductService();
  Future<List<ProductModel>>? _resultsFuture;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _activeQuery = widget.initialQuery;
      _resultsFuture = _search(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ProductModel>> _search(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    return _productService.searchProducts(query.trim());
  }

  void _performSearch(String query) {
    setState(() {
      _activeQuery = query;
      _resultsFuture = _search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF93C5FD)];

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
              // Header with search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16, right: 12),
                                  child: Icon(Icons.search,
                                      color: Colors.white, size: 20),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: widget.initialQuery.isEmpty,
                                    style: const TextStyle(color: Colors.white),
                                    cursorColor: Colors.white,
                                    onChanged: (value) {
                                      setState(() {
                                        _activeQuery = value;
                                      });
                                    },
                                    onSubmitted: _performSearch,
                                    decoration: InputDecoration(
                                      hintText: 'Search phones, laptops...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.white, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _activeQuery = '';
                                        _resultsFuture = Future.value([]);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Results
              Expanded(
                child: _activeQuery.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 80,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Search for phones or laptops',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FutureBuilder<List<ProductModel>>(
                        future: _resultsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Search failed. Please try again.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            );
                          }

                          final products = snapshot.data ?? [];
                          if (products.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results found for "$_activeQuery"',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return _SearchResultCard(product: product);
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

class _SearchResultCard extends StatelessWidget {
  final ProductModel product;

  const _SearchResultCard({required this.product});

  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: Colors.white.withOpacity(0.16),
                  child: _isNetworkImage(product.image)
                      ? Image.network(
                          product.image,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.prefer,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.smartphone,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.smartphone, color: Colors.white),
                ),
              ),
              title: Text(
                product.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    product.brand,
                    product.category,
                    product.specs ?? '',
                  ].where((part) => part.isNotEmpty).join(' • '),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Text(
                'Rs ${product.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(product: product),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
