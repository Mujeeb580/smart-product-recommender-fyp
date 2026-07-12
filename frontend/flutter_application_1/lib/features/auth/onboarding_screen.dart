import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _waveController;
  late AnimationController _sparkleController;
  late AnimationController _rotateController;

  final List<OnboardingPage> pages = [
    OnboardingPage(
      title: 'Smart AI Recommendations',
      description:
          'Get personalized product suggestions powered by advanced AI technology',
      icon: Icons.auto_awesome,
      iconColor: const Color(0xFF6B5FEF),
      animationType: AnimationType.sparkle,
    ),
    OnboardingPage(
      title: 'Voice & Text Search',
      description: 'Search using your voice or text in your preferred language',
      icon: Icons.mic,
      iconColor: const Color(0xFF1D9BF0),
      animationType: AnimationType.wave,
    ),
    OnboardingPage(
      title: 'Multilingual Support',
      description: 'Available in English and Roman Urdu for your convenience',
      icon: Icons.language,
      iconColor: const Color(0xFF17B26A),
      animationType: AnimationType.rotate,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Wave animation controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Sparkle animation controller
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Rotate animation controller
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _waveController.dispose();
    _sparkleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Page View
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return _buildPage(pages[index]);
            },
          ),
          // Skip Button
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    onTap: _goToLogin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade800.withOpacity(0.8),
                            Colors.grey.shade900.withOpacity(0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.7),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Page Indicators and Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (index) => Container(
                          width: index == _currentPage ? 32 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? const Color(0xFF6B5FEF)
                                : Colors.grey.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Next/Get Started Button
                    GestureDetector(
                      onTap: () {
                        if (_currentPage == pages.length - 1) {
                          _goToLogin();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6B5FEF), Color(0xFF5B4FDF)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6B5FEF).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          _currentPage == pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isSmallMobile = constraints.maxWidth < 400;
        final iconSize = isMobile
            ? (isSmallMobile ? 100.0 : 120.0)
            : min(140.0, constraints.maxWidth * 0.35);
        final isCompact = constraints.maxHeight < 700;
        final titleSize = isMobile
            ? (isCompact ? 20.0 : 24.0)
            : (isCompact ? 24.0 : 28.0);
        final descSize = isMobile
            ? (isCompact ? 14.0 : 16.0)
            : (isCompact ? 14.0 : 16.0);
        final verticalGap = isMobile
            ? (isCompact ? 20.0 : 30.0)
            : (isCompact ? 24.0 : 40.0);
        final horizontalPad = isMobile
            ? 24.0
            : max(20.0, constraints.maxWidth * 0.08);

        return SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 480,
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: isMobile ? 20 : 16,
                  ),
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isMobile ? 160 : 32),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isMobile && isCompact)
                          SizedBox(height: 20)
                        else
                          SizedBox(height: isMobile ? 40 : 60),
                        SizedBox(
                          width: iconSize,
                          height: iconSize,
                          child: _buildAnimatedIcon(page),
                        ),
                        SizedBox(height: verticalGap),
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8.0 : 0.0,
                          ),
                          child: Text(
                            page.description,
                            style: TextStyle(
                              fontSize: descSize,
                              color: Colors.grey.shade300,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMobile && isCompact)
                          SizedBox(height: 20)
                        else
                          SizedBox(height: isMobile ? 40 : 60),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedIcon(OnboardingPage page) {
    switch (page.animationType) {
      case AnimationType.wave:
        return _buildWaveAnimation(page);
      case AnimationType.sparkle:
        return _buildSparkleAnimation(page);
      case AnimationType.rotate:
        return _buildRotateAnimation(page);
    }
  }

  Widget _buildWaveAnimation(OnboardingPage page) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // SIRI-like animated bars
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: page.iconColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          width: 4,
                          height:
                              20 +
                              (30 *
                                      sin(
                                        _waveController.value * 6.28 +
                                            (i * 0.4),
                                      ))
                                  .abs(),
                          decoration: BoxDecoration(
                            color: page.iconColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSparkleAnimation(OnboardingPage page) {
    return AnimatedBuilder(
      animation: _sparkleController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Robot-like face with animated eyes
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: page.iconColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Robot head
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        border: Border.all(color: page.iconColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Eyes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 12,
                                height:
                                    12 +
                                    (8 * sin(_sparkleController.value * 6.28))
                                        .abs(),
                                decoration: BoxDecoration(
                                  color: page.iconColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                width: 12,
                                height:
                                    12 +
                                    (8 *
                                            sin(
                                              _sparkleController.value * 6.28 +
                                                  1.5,
                                            ))
                                        .abs(),
                                decoration: BoxDecoration(
                                  color: page.iconColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Mouth
                          Container(
                            width: 20,
                            height: 2,
                            color: page.iconColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRotateAnimation(OnboardingPage page) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: page.iconColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring with language indicators
                    Transform.rotate(
                      angle: _rotateController.value * 2.0,
                      child: Container(
                        width: 95,
                        height: 95,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.iconColor.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Language dots around the circle
                            for (int i = 0; i < 8; i++)
                              Positioned(
                                left: 47.5 + 35 * cos(i * pi / 4) - 3,
                                top: 47.5 + 35 * sin(i * pi / 4) - 3,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: page.iconColor.withOpacity(
                                      0.4 +
                                          0.4 *
                                              sin(
                                                _rotateController.value * 6.28 +
                                                    i * 0.8,
                                              ).abs(),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Inner rotating ring (opposite direction)
                    Transform.rotate(
                      angle: -_rotateController.value * 1.5,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.iconColor.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Inner language symbols
                            for (int i = 0; i < 4; i++)
                              Positioned(
                                left: 35 + 20 * cos(i * pi / 2) - 4,
                                top: 35 + 20 * sin(i * pi / 2) - 4,
                                child: AnimatedOpacity(
                                  opacity:
                                      0.6 +
                                      0.4 *
                                          sin(
                                            _rotateController.value * 4 +
                                                i * 1.5,
                                          ).abs(),
                                  duration: const Duration(milliseconds: 100),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: page.iconColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Pulsating center globe icon
                    AnimatedScale(
                      scale: 1.0 + 0.1 * sin(_rotateController.value * 4).abs(),
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: page.iconColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.language,
                          size: 28,
                          color: page.iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final AnimationType animationType;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.animationType,
  });
}

enum AnimationType { wave, sparkle, rotate }
