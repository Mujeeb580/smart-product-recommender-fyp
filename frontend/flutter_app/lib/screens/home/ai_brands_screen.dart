import 'package:flutter/material.dart';

class AIBrandsScreen extends StatelessWidget {
  const AIBrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> brands = [
      {
        "name": "ChatGPT",
        "price": "129",
        "rating": "4.9",
        "color": const Color(0xFF10B981),
        "icon": Icons.chat_bubble_outline,
      },
      {
        "name": "Microsoft",
        "price": "199",
        "rating": "4.8",
        "color": const Color(0xFF3B82F6),
        "icon": Icons.window,
      },
      {
        "name": "Trell",
        "price": "89",
        "rating": "4.7",
        "color": const Color(0xFF06B6D4),
        "icon": Icons.travel_explore,
      },
      {
        "name": "Discord",
        "price": "49",
        "rating": "4.6",
        "color": const Color(0xFF8B5CF6),
        "icon": Icons.discord,
      },
      {
        "name": "Slack",
        "price": "99",
        "rating": "4.7",
        "color": const Color(0xFF7C3AED),
        "icon": Icons.tag,
      },
      {
        "name": "HP",
        "price": "299",
        "rating": "4.5",
        "color": const Color(0xFF3B82F6),
        "icon": Icons.computer,
      },
      {
        "name": "Lenovo",
        "price": "249",
        "rating": "4.6",
        "color": const Color(0xFFEF4444),
        "icon": Icons.laptop_chromebook,
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
          "AI Brands",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "All Brands",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Explore top AI and tech brands",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: brands.length,
              itemBuilder: (context, index) {
                return _buildBrandCard(brands[index]);
              },
            ),
          ),
          // Footer with deals
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Authorized Shop Top Brands",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.apple,
                        size: 30,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "iPhone 15 Pro Max",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "\$1199",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        "Buy",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand["color"],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: brand["color"].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(brand["icon"], size: 28, color: brand["color"]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand["name"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      brand["rating"],
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$${brand["price"]}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  "Buy",
                  style: TextStyle(
                    color: brand["color"],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
