import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final bool showSimilarity;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showSimilarity = true,
  });

  bool _isNetworkImage(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  String _priceLabel(double price) {
    final value = price.toStringAsFixed(0);
    final formatted = value.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return 'Rs $formatted';
  }

  String? _specSummary() {
    final values = <String>[
      if (product.ram?.trim().isNotEmpty ?? false) product.ram!.trim(),
      if (product.storage?.trim().isNotEmpty ?? false) product.storage!.trim(),
      if (product.processor?.trim().isNotEmpty ?? false)
        product.processor!.trim(),
    ];
    return values.isEmpty ? null : values.take(2).join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final specs = _specSummary();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .45)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF4F2FA),
                    padding: const EdgeInsets.all(12),
                    child: _buildImage(),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _badge(product.category, Colors.black87),
                  ),
                  if (showSimilarity && product.similarityScore > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _badge(
                        '${(product.similarityScore * 100).round()}% match',
                        AppTheme.primaryColor,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: .7,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  SizedBox(height: specs == null ? 22 : 7),
                  if (specs != null)
                    Text(
                      specs,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _priceLabel(product.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _buildImage() {
    if (product.image.isEmpty) {
      return const Center(
        child: Icon(Icons.devices_rounded, size: 58, color: Colors.black26),
      );
    }
    if (_isNetworkImage(product.image)) {
      return Image.network(
        product.image,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.devices_rounded, size: 58, color: Colors.black26),
        ),
      );
    }
    return Image.asset(
      product.image,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.devices_rounded, size: 58, color: Colors.black26),
      ),
    );
  }
}
