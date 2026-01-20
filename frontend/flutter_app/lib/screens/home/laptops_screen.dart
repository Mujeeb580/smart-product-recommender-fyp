import 'package:flutter/material.dart';

class LaptopsScreen extends StatefulWidget {
  const LaptopsScreen({super.key});

  @override
  State<LaptopsScreen> createState() => _LaptopsScreenState();
}

class _LaptopsScreenState extends State<LaptopsScreen> {
  String selectedTab = "Brands";

  final List<Map<String, dynamic>> products = [
    {
      "name": "MacBook Pro M3",
      "price": "\$1299",
      "rating": "4.9",
      "specs": "16GB RAM, 512GB SSD",
    },
    {
      "name": "Dell XPS 15",
      "price": "\$1199",
      "rating": "4.7",
      "specs": "16GB RAM, 1TB SSD",
    },
    {
      "name": "HP Spectre x360",
      "price": "\$1099",
      "rating": "4.6",
      "specs": "16GB RAM, 512GB SSD",
    },
    {
      "name": "Lenovo ThinkPad X1",
      "price": "\$1399",
      "rating": "4.8",
      "specs": "32GB RAM, 1TB SSD",
    },
    {
      "name": "ASUS ZenBook 14",
      "price": "\$899",
      "rating": "4.5",
      "specs": "8GB RAM, 512GB SSD",
    },
    {
      "name": "Microsoft Surface Laptop",
      "price": "\$999",
      "rating": "4.6",
      "specs": "16GB RAM, 256GB SSD",
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          "Laptop Screens",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildTab("Brands", selectedTab == "Brands"),
                const SizedBox(width: 12),
                _buildTab("Favorites", selectedTab == "Favorites"),
                const SizedBox(width: 12),
                _buildTab("Latest Deals", selectedTab == "Latest Deals"),
              ],
            ),
          ),
          // Product List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(products[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
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
            child: Icon(Icons.laptop_mac, size: 40, color: Colors.grey[400]),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product["specs"],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      product["rating"],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    Text(
                      product["price"],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Buy Button
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              "Buy",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
