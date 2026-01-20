import 'package:flutter/material.dart';
import 'filters_screen.dart';

class ProductResultsScreen extends StatefulWidget {
  final String searchQuery;

  const ProductResultsScreen({super.key, required this.searchQuery});

  @override
  State<ProductResultsScreen> createState() => _ProductResultsScreenState();
}

class _ProductResultsScreenState extends State<ProductResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _appliedFilters;

  final List<Map<String, dynamic>> _products = [
    {
      "name": "Wireless Headphones",
      "category": "Audio",
      "price": 239.99,
      "originalPrice": 299,
      "rating": 4.8,
      "reviews": 127,
      "color": const Color(0xFFFCD34D),
      "icon": Icons.headphones,
      "discount": "20%",
    },
    {
      "name": "Smart Watch Ultra",
      "category": "Wearables",
      "price": 399.99,
      "rating": 4.9,
      "reviews": 243,
      "color": Colors.grey[300],
      "icon": Icons.watch,
    },
    {
      "name": "Premium Keyboard",
      "category": "Accessories",
      "price": 89.99,
      "rating": 4.6,
      "reviews": 89,
      "color": Colors.black,
      "icon": Icons.keyboard,
      "discount": "15%",
    },
    {
      "name": "Bluetooth Speaker",
      "category": "Audio",
      "price": 179,
      "rating": 4.7,
      "reviews": 156,
      "color": Colors.black87,
      "icon": Icons.speaker,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilters() async {
    final filters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FiltersScreen(currentFilters: _appliedFilters),
      ),
    );

    if (filters != null) {
      setState(() {
        _appliedFilters = filters;
        // Apply filters to products list here
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "Search Results",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "Electronics",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const Icon(Icons.close, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${_products.length} products found",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(_products[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFilters,
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.filter_list, color: Colors.white),
        label: const Text("Filters", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image with badges
          Stack(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: product["color"] ?? Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Icon(product["icon"], size: 50, color: Colors.white70),
                ),
              ),
              if (product["discount"] != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product["discount"],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          // Product Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product["category"],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  product["name"],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "${product['rating']}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      " (${product['reviews']})",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "\$${product['price']}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    if (product["originalPrice"] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        "\$${product['originalPrice']}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
