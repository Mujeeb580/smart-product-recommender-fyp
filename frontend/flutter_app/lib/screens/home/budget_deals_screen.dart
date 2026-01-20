import 'package:flutter/material.dart';

class BudgetDealsScreen extends StatelessWidget {
  const BudgetDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> deals = [
      {
        "name": "Budget Deals",
        "products": 2,
        "discount": "50%",
        "price": "\$550",
        "color": const Color(0xFF10B981),
      },
      {
        "name": "Realme 12 Pro",
        "products": 1,
        "discount": "30%",
        "price": "\$299",
        "color": const Color(0xFF10B981),
      },
      {
        "name": "Vivo Y36",
        "products": 1,
        "discount": "25%",
        "price": "\$249",
        "color": const Color(0xFF10B981),
      },
      {
        "name": "Lenovo IdeaPad 3",
        "products": 1,
        "discount": "40%",
        "price": "\$449",
        "color": const Color(0xFF10B981),
      },
      {
        "name": "Oppo A78",
        "products": 1,
        "discount": "20%",
        "price": "\$199",
        "color": const Color(0xFF10B981),
      },
      {
        "name": "Redmi Note 13",
        "products": 1,
        "discount": "35%",
        "price": "\$189",
        "color": const Color(0xFF10B981),
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
          "Budget Deals",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: deals.length,
        itemBuilder: (context, index) {
          return _buildDealCard(deals[index]);
        },
      ),
    );
  }

  Widget _buildDealCard(Map<String, dynamic> deal) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.shopping_bag,
                size: 50,
                color: Colors.grey[400],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deal["name"],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${deal["products"]} products",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: deal["color"].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        deal["discount"],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: deal["color"],
                        ),
                      ),
                    ),
                    Text(
                      deal["price"],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      "View Deal",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
