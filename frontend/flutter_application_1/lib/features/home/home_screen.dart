import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/theme_provider.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import 'profile_screen.dart';
import '../../widgets/glassy_shine.dart';
import 'smartphones_screen.dart';
import 'laptops_screen.dart';
import 'voice_assistant_screen.dart';
import 'chat_screen.dart';
import '../products/product_detail_screen.dart';
import '../../models/product_model.dart';
import 'search_results_screen.dart';
import '../products/product_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolling = _scrollController.position.isScrollingNotifier.value;
    if (isScrolling != _isScrolling) {
      setState(() {
        _isScrolling = isScrolling;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme brightness from ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final gradientColors = themeProvider.currentGradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 24),
                child: RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepaintBoundary(
                        child: _HeroHeader(
                          onProfileTap: () {
                            // The profile is now accessible via bottom nav
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RepaintBoundary(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(title: 'categories'.tr()),
                              const SizedBox(height: 14),
                              _CategoriesSection(isScrolling: _isScrolling),
                              const SizedBox(height: 24),
                              _SectionTitle(title: 'quick_filters'.tr()),
                              const SizedBox(height: 14),
                              const _QuickFilters(),
                              const SizedBox(height: 24),
                              _AiCard(),
                              const SizedBox(height: 24),
                              _SectionTitle(title: 'trending_deals'.tr()),
                              const SizedBox(height: 14),
                              const _HorizontalProducts(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const GlassyShine(opacity: 0.12),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;

  const _HeroHeader({this.onProfileTap});

  String _displayName(String? displayName, String? email) {
    final savedName = displayName?.trim() ?? '';
    if (savedName.isNotEmpty) return savedName;

    final localPart = (email ?? '').split('@').first.trim();
    if (localPart.isEmpty) return 'there';

    final parts = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty);

    return parts
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    final userName = _displayName(
      currentUser?.displayName,
      currentUser?.email,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                                letterSpacing: 0.5,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'What are you looking for?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onProfileTap,
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
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SearchBar(),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToSearch() {
    final query = _searchController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          initialQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 52,
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
                child: Icon(Icons.search, color: Colors.white, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  onSubmitted: (value) => _navigateToSearch(),
                  onTap: _navigateToSearch,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'search_electronics'.tr(),
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: true,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(Icons.mic, color: Colors.white, size: 22),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const VoiceAssistantScreen(),
                      ),
                    );
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
    );
  }
}

class _CategoriesSection extends StatefulWidget {
  final bool isScrolling;
  const _CategoriesSection({required this.isScrolling});

  @override
  State<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<_CategoriesSection> {
  late final PageController _pageController;
  int _activeIndex = 0;

  final List<_Category> _categories = [
    _Category(
      'mobiles'.tr(),
      '250+ ${'models'.tr()}',
      Icons.smartphone,
      [
        0xFF4E6BFF,
        0xFF3CA6FF,
        0xFF6366F1,
      ],
      'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&h=600&fit=crop&crop=center&auto=format&q=80',
      'latest_smartphones'.tr(),
    ),
    _Category(
      'laptops'.tr(),
      '180+ ${'models'.tr()}',
      Icons.laptop_mac,
      [
        0xFFFB4DA7,
        0xFFFB7C38,
        0xFFEC4899,
      ],
      'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=800&h=600&fit=crop&crop=center&auto=format&q=80',
      'high_performance_laptops'.tr(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleTap(_Category category) {
    if (category.title == 'mobiles'.tr()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SmartphonesScreen(),
        ),
      );
    } else if (category.title == 'laptops'.tr()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LaptopsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 225,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            onPageChanged: (index) {
              setState(() {
                _activeIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CategoryCard(
                  category: category,
                  isScrolling: widget.isScrolling,
                  onTap: () => _handleTap(category),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_categories.length, (index) {
            final isActive = index == _activeIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.95)
                    : Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Category {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<int> gradient;
  final String imageUrl;
  final String description;
  _Category(this.title, this.subtitle, this.icon, this.gradient, this.imageUrl,
      this.description);
}

class _CategoryCard extends StatefulWidget {
  final _Category category;
  final VoidCallback? onTap;
  final bool isScrolling;
  const _CategoryCard(
      {required this.category, this.onTap, required this.isScrolling});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);
  }

  @override
  void didUpdateWidget(_CategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScrolling != oldWidget.isScrolling) {
      if (widget.isScrolling) {
        _animationController.stop();
        _pulseController.stop();
      } else {
        _animationController.repeat();
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(widget.category.gradient.first)
                            .withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // High-Quality Background Image
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  widget.category.imageUrl,
                                  fit: BoxFit.cover,
                                  webHtmlElementStrategy:
                                      WebHtmlElementStrategy.prefer,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          transform: GradientRotation(
                                              _rotationAnimation.value *
                                                  2 *
                                                  3.14159),
                                          colors: widget.category.gradient
                                              .map((c) =>
                                                  Color(c).withOpacity(0.6))
                                              .toList(),
                                        ),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white.withOpacity(0.7),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          transform: GradientRotation(
                                              _rotationAnimation.value *
                                                  2 *
                                                  3.14159),
                                          colors: widget.category.gradient
                                              .map((c) =>
                                                  Color(c).withOpacity(0.6))
                                              .toList(),
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          widget.category.icon,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 50,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Animated Gradient Overlay
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        transform: GradientRotation(
                                            _rotationAnimation.value *
                                                1 *
                                                3.14159),
                                        colors: [
                                          widget.category.gradient
                                              .map((c) =>
                                                  Color(c).withOpacity(0.3))
                                              .toList()[0],
                                          Colors.transparent,
                                          widget.category.gradient
                                              .map((c) =>
                                                  Color(c).withOpacity(0.2))
                                              .toList()[1],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Optimized animated overlay dots
                            if (!widget.isScrolling)
                              ...List.generate(4, (index) {
                                final offset = (index * 90.0) % 360;
                                return Positioned(
                                  left: 50 +
                                      (30 * (index % 2)) +
                                      (8 * _pulseAnimation.value),
                                  top: 30 +
                                      (25 * (index ~/ 2)) +
                                      (4 * _pulseAnimation.value),
                                  child: Transform.rotate(
                                    angle: (_rotationAnimation.value *
                                            1.5 *
                                            3.14159) +
                                        (offset * 3.14159 / 180),
                                    child: Container(
                                      width: 3 + (1.5 * _pulseAnimation.value),
                                      height: 3 + (1.5 * _pulseAnimation.value),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(
                                            0.25 * _pulseAnimation.value),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            // Enhanced Content overlay for text readability
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.1),
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            // Main Content
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Animated Icon
                                    Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: widget.category.gradient
                                                .map((c) => Color(c))
                                                .toList(),
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(widget
                                                      .category.gradient.first)
                                                  .withOpacity(0.5),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Transform.rotate(
                                          angle: _rotationAnimation.value * 0.1,
                                          child: Icon(
                                            widget.category.icon,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Title and subtitle
                                    Text(
                                      widget.category.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.1,
                                        shadows: [
                                          Shadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.visible,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.category.subtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.visible,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      widget.category.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                Colors.white.withOpacity(0.75),
                                            height: 1.1,
                                            fontSize: 9,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters();

  @override
  Widget build(BuildContext context) {
    final filters = [
      _Filter('budget', 'budget'.tr(), Icons.attach_money, const Color(0xFF10B981)),
      _Filter('brand', 'brand'.tr(), Icons.sell_outlined, const Color(0xFFFB923C)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: filters.map((f) => _FilterChip(filter: f)).toList(),
    );
  }
}

class _Filter {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  _Filter(this.key, this.label, this.icon, this.color);
}

class _FilterChip extends StatelessWidget {
  final _Filter filter;
  const _FilterChip({required this.filter});

  Future<void> _openFilteredProducts(
    BuildContext context, {
    required String title,
    required Future<List<ProductModel>> future,
  }) async {
    try {
      final products = await future;
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProductListScreen(
            initialProducts: products,
            title: title,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load filtered products. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productService = ProductService();

    return GestureDetector(
      onTap: () {
        switch (filter.key) {
        case 'budget':
          _openFilteredProducts(
            context,
            title: 'Budget Picks',
            future: productService.filterByPriceRange(0, 50000),
          );
          return;
        case 'brand':
          _openFilteredProducts(
            context,
            title: 'Samsung Phones',
            future: productService.searchProducts('Samsung'),
          );
          return;
        case 'rating':
          _openFilteredProducts(
            context,
            title: 'Top Rated Picks',
            future: productService.fetchRecommendedProducts(
                query: 'best rated phone'),
          );
          return;
        case 'same_day':
          _openFilteredProducts(
            context,
            title: 'Fast Delivery Picks',
            future: productService.fetchCollectionProducts(
                collection: 'phones', limit: 40),
          );
          return;
        default:
          return;
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: filter.color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(filter.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  filter.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'AI Recommendations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get personalized suggestions based on your preferences',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    foregroundColor: const Color(0xFF5B21B6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChatScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Chat with AI Assistant',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalProducts extends StatelessWidget {
  const _HorizontalProducts();

  @override
  Widget build(BuildContext context) {
    final productService = ProductService();

    return FutureBuilder<List<ProductModel>>(
      future: productService.fetchCollectionProducts(
          collection: 'phones', limit: 10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          );
        }

        if (snapshot.hasError || (snapshot.data ?? []).isEmpty) {
          return SizedBox(
            height: 180,
            child: Center(
              child: Text(
                'No trending products available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }

        final items = List<ProductModel>.from(snapshot.data!)
          ..sort((a, b) => b.price.compareTo(a.price));
        final displayItems = items.take(5).toList();

        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final product = displayItems[index];
              return _ProductCard(product: product);
            },
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 240,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.1),
                    child: product.image.isEmpty
                        ? Container(color: Colors.white.withOpacity(0.1))
                        : product.image.startsWith('http')
                            ? Image.network(
                                product.image,
                                fit: BoxFit.cover,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.white.withOpacity(0.1),
                                  );
                                },
                              )
                            : Image.asset(
                                product.image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.white.withOpacity(0.1),
                                  );
                                },
                              ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${product.price.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
