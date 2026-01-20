import 'package:flutter/material.dart';

class FiltersScreen extends StatefulWidget {
  final Map<String, dynamic>? currentFilters;

  const FiltersScreen({super.key, this.currentFilters});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  String _selectedSort = "Most Relevant";
  RangeValues _priceRange = const RangeValues(0, 1000);
  Set<String> _selectedCategories = {};

  final List<String> _sortOptions = [
    "Most Relevant",
    "Price: Low to High",
    "Price: High to Low",
    "Highest Rated",
    "Most Popular",
  ];

  final List<String> _categories = ["Audio", "Wearables", "Accessories"];

  @override
  void initState() {
    super.initState();
    if (widget.currentFilters != null) {
      _selectedSort = widget.currentFilters!['sort'] ?? "Most Relevant";
      _priceRange =
          widget.currentFilters!['priceRange'] ?? const RangeValues(0, 1000);
      _selectedCategories = Set<String>.from(
        widget.currentFilters!['categories'] ?? [],
      );
    }
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'sort': _selectedSort,
      'priceRange': _priceRange,
      'categories': _selectedCategories.toList(),
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedSort = "Most Relevant";
      _priceRange = const RangeValues(0, 1000);
      _selectedCategories.clear();
    });
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Filters",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Set your preferences",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Filters Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sort By Section
                        const Text(
                          "Sort By",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._sortOptions.map((option) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildSortOption(option),
                          );
                        }),

                        const SizedBox(height: 24),

                        // Price Range Section
                        const Text(
                          "Price Range",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Min",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              "Max",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${_priceRange.start.toInt()}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${_priceRange.end.toInt()}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 1000,
                          divisions: 100,
                          activeColor: const Color(0xFF7C3AED),
                          onChanged: (RangeValues values) {
                            setState(() {
                              _priceRange = values;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "\$0",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              "\$1000+",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Categories Section
                        const Text(
                          "Categories",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((category) {
                            final isSelected = _selectedCategories.contains(
                              category,
                            );
                            return FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                              },
                              selectedColor: const Color(
                                0xFF7C3AED,
                              ).withOpacity(0.2),
                              checkmarkColor: const Color(0xFF7C3AED),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF7C3AED)
                                    : Colors.grey[700],
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF7C3AED)
                                    : Colors.grey[300]!,
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetFilters,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF7C3AED)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Reset All",
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String option) {
    final isSelected = _selectedSort == option;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSort = option;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEC4899) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              option,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
