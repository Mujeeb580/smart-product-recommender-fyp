import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _quickCommands = [
    "Show me electronics",
    "Best deals today",
    "New arrivals",
    "Top rated products",
  ];

  final List<String> _recentSearches = [
    "Wireless headphones",
    "Smart watch",
    "Laptop accessories",
    "Gaming keyboard",
  ];

  final List<Map<String, dynamic>> _trendingNow = [
    {"name": "iPhone 13 Pro Max", "icon": Icons.phone_iphone},
    {"name": "MacBook Pro M2", "icon": Icons.laptop_mac},
    {"name": "AirPods Pro", "icon": Icons.headphones},
    {"name": "iPad Air", "icon": Icons.tablet_mac},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7C3AED),
      body: SafeArea(
        child: Column(
          children: [
            // ==== Top Header with Search ====
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          // Navigate back if needed
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "Search",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Find what you're looking for",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search or type keywords",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.filter_list,
                            color: Color(0xFF7C3AED),
                          ),
                          onPressed: () {},
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==== Content Area ====
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Commands
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Quick Commands",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickCommands.map((command) {
                          return _buildCommandChip(command);
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Recent Searches
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Recent Searches",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._recentSearches.map((search) {
                        return _buildRecentSearchItem(search);
                      }).toList(),

                      const SizedBox(height: 24),

                      // Trending Now
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_up,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Trending Now",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._trendingNow.map((item) {
                        return _buildTrendingItem(
                          item['name'] as String,
                          item['icon'] as IconData,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7C3AED),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRecentSearchItem(String search) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(search, style: const TextStyle(fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingItem(String name, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
