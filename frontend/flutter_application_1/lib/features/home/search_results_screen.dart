import 'dart:ui';
import 'package:flutter/material.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  List<_SearchItem> _filteredResults = [];

  final List<_SearchItem> _allProducts = [
    // Smartphones
    _SearchItem('Samsung Galaxy S24', 'Flagship • 256GB', 329999, 'Smartphone',
        Icons.smartphone),
    _SearchItem(
        'iPhone 15 Pro', 'Pro • 256GB', 399999, 'Smartphone', Icons.smartphone),
    _SearchItem('iPhone 15 Pro Max', 'Latest iPhone with titanium design',
        449999, 'Smartphone', Icons.smartphone),
    _SearchItem('Samsung Galaxy S24 Ultra', 'Premium Android phone with S Pen',
        379999, 'Smartphone', Icons.smartphone),
    _SearchItem('Google Pixel 8', 'AI Camera • 128GB', 259999, 'Smartphone',
        Icons.smartphone),
    _SearchItem('Xiaomi 14', 'Value Flagship • 256GB', 219999, 'Smartphone',
        Icons.smartphone),
    _SearchItem('OnePlus 12', 'Fast & Smooth • 256GB', 239999, 'Smartphone',
        Icons.smartphone),
    _SearchItem('Infinix Zero 30', 'Budget • 256GB', 74999, 'Smartphone',
        Icons.smartphone),

    // Laptops
    _SearchItem('Dell XPS 15', 'Creator • i7 • 16GB', 459999, 'Laptop',
        Icons.laptop_mac),
    _SearchItem(
        'MacBook Pro 14', 'M3 • 16GB', 599999, 'Laptop', Icons.laptop_mac),
    _SearchItem('MacBook Pro 16"', 'Powerful laptop with M3 Max chip', 599999,
        'Laptop', Icons.laptop_mac),
    _SearchItem('HP Spectre x360', 'OLED • i7 • 16GB', 379999, 'Laptop',
        Icons.laptop_mac),
    _SearchItem('Lenovo ThinkPad X1', 'Business • i7 • 16GB', 419999, 'Laptop',
        Icons.laptop_mac),
    _SearchItem('Asus ROG Zephyrus', 'Gaming • RTX • 16GB', 489999, 'Laptop',
        Icons.laptop_mac),
    _SearchItem('Acer Swift 3', 'Budget • i5 • 8GB', 179999, 'Laptop',
        Icons.laptop_mac),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredResults = [];
      } else {
        _filteredResults = _allProducts.where((product) {
          final searchLower = query.toLowerCase();
          return product.title.toLowerCase().contains(searchLower) ||
              product.subtitle.toLowerCase().contains(searchLower) ||
              product.category.toLowerCase().contains(searchLower);
        }).toList();
      }
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
                                    onChanged: _performSearch,
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
                                      _performSearch('');
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
                child: _searchController.text.isEmpty
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
                    : _filteredResults.isEmpty
                        ? Center(
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
                                  'No results found for "${_searchController.text}"',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: _filteredResults.length,
                            itemBuilder: (context, index) {
                              final item = _filteredResults[index];
                              return _SearchResultCard(item: item);
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

class _SearchItem {
  final String title;
  final String subtitle;
  final int price;
  final String category;
  final IconData icon;

  _SearchItem(this.title, this.subtitle, this.price, this.category, this.icon);
}

class _SearchResultCard extends StatelessWidget {
  final _SearchItem item;

  const _SearchResultCard({required this.item});

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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR ${item.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
