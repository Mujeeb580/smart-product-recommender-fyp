import 'package:flutter/material.dart';

class MobilesScreen extends StatelessWidget {
  const MobilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> products = [
      {
        "name": "iPhone 15 Pro",
        "price": "\$999",
        "rating": "4.8",
        "hasImage": false,
      },
      {
        "name": "Samsung Galaxy S24",
        "price": "\$849",
        "rating": "4.7",
        "hasImage": false,
      },
      {
        "name": "OnePlus 12",
        "price": "\$699",
        "rating": "4.6",
        "hasImage": false,
      },
      {
        "name": "Google Pixel 8 Pro",
        "price": "\$899",
        "rating": "4.7",
        "hasImage": false,
      },
      {
        "name": "Xiaomi 14",
        "price": "\$599",
        "rating": "4.5",
        "hasImage": false,
      },
      {
        "name": "OPPO Find X7",
        "price": "\$749",
        "rating": "4.6",
        "hasImage": false,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mobile Phones",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return _buildProductCard(products[index]);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image Placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.phone_android, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(width: 16),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product["name"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      product["rating"],
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product["price"],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ),
          // Buy Button
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("Buy", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
