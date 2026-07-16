import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/product_model.dart';
import '../../core/theme.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    final maxWidth = isDesktop ? 1200.0 : double.infinity;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 24.0 : 20.0);
    final imageHeight = isDesktop ? 500.0 : (isTablet ? 400.0 : 300.0);
    final hasImage = product.image.isNotEmpty;
    final hasStructuredSpecs = [
      product.ram,
      product.storage,
      product.processor,
      product.gpu,
      product.battery,
      product.camera,
    ].any((value) => value != null && value.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F0F23),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Back Button
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 16, horizontalPadding, 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                          const SizedBox(width: 16),
                          Text(
                            'Product Details',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),

                    if (hasImage) ...[
                      // Product Image Section
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: double.infinity,
                              height: imageHeight,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: _isNetworkImage(product.image)
                                  ? Image.network(
                                      product.image,
                                      fit: BoxFit.contain,
                                      webHtmlElementStrategy:
                                          WebHtmlElementStrategy.prefer,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.smartphone,
                                            size: 80,
                                            color: Colors.white54,
                                          ),
                                        );
                                      },
                                    )
                                  : Image.asset(
                                      product.image,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.smartphone,
                                            size: 80,
                                            color: Colors.white54,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Product Info
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Brand
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    product.brand,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 12,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Product Name
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize:
                                        isDesktop ? 32 : (isTablet ? 28 : 24),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Category
                                Row(
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      product.category,
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16 : 14,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                if (product.ram != null &&
                                    product.ram!.isNotEmpty) ...[
                                  _detailTile(context, 'RAM', product.ram!),
                                  const SizedBox(height: 12),
                                ],
                                if (product.storage != null &&
                                    product.storage!.isNotEmpty) ...[
                                  _detailTile(
                                      context, 'Storage', product.storage!),
                                  const SizedBox(height: 12),
                                ],
                                if (product.processor != null &&
                                    product.processor!.isNotEmpty) ...[
                                  _detailTile(
                                      context, 'Processor', product.processor!),
                                  const SizedBox(height: 12),
                                ],
                                if (product.gpu != null &&
                                    product.gpu!.isNotEmpty) ...[
                                  _detailTile(context, 'GPU', product.gpu!),
                                  const SizedBox(height: 12),
                                ],
                                if (product.battery != null &&
                                    product.battery!.isNotEmpty) ...[
                                  _detailTile(
                                      context, 'Battery', product.battery!),
                                  const SizedBox(height: 12),
                                ],
                                if (product.camera != null &&
                                    product.camera!.isNotEmpty) ...[
                                  _detailTile(
                                      context, 'Camera', product.camera!),
                                  const SizedBox(height: 12),
                                ],
                                if (!hasStructuredSpecs &&
                                    product.specs != null &&
                                    product.specs!.trim().isNotEmpty) ...[
                                  _detailTile(
                                    context,
                                    'Additional Specifications',
                                    product.specs!,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Price
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF0E7490)
                                            .withOpacity(0.3),
                                        const Color(0xFF22D3EE)
                                            .withOpacity(0.3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Price',
                                            style: TextStyle(
                                              fontSize: isDesktop ? 14 : 12,
                                              color:
                                                  Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'PKR ${product.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                            style: TextStyle(
                                              fontSize: isDesktop
                                                  ? 36
                                                  : (isTablet ? 32 : 28),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Description
                                if (product.description != null) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 20 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    product.description!,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 16 : 14,
                                      color: Colors.white.withOpacity(0.8),
                                      height: 1.6,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 32),

                                // Action Buttons
                                if (isDesktop || isTablet)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildButton(
                                          context,
                                          'View at Store',
                                          true,
                                          isDesktop,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildButton(
                                          context,
                                          'Back',
                                          false,
                                          isDesktop,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      _buildButton(
                                        context,
                                        'View at Store',
                                        true,
                                        isDesktop,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildButton(
                                        context,
                                        'Back',
                                        false,
                                        isDesktop,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, String text, bool isPrimary, bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 60 : 56,
      child: isPrimary
          ? ElevatedButton(
              onPressed: () {
                if (product.url == null || product.url!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No product link available for this item.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF0E7490),
                    ),
                  );
                  return;
                }

                _openOrCopyProductLink(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E7490),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _detailTile(BuildContext context, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrCopyProductLink(BuildContext context) async {
    final link = product.url;
    if (link == null || link.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product link is not valid.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0E7490),
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened) {
      Clipboard.setData(ClipboardData(text: link));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open browser. Link copied to clipboard.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0E7490),
        ),
      );
    }
  }
}
