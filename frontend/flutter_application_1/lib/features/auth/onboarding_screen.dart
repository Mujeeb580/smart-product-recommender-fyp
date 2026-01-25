import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_application_1/features/auth/login_screen.dart';

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
      description: 'Get personalized product suggestions powered by advanced AI technology',
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
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: _goToLogin,
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Page Indicators and Buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Page Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => Container(
                      width: index == _currentPage ? 40 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _currentPage
                            ? const Color(0xFF6B5FEF)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Next/Get Started Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
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
                          colors: [
                            Color(0xFF6B5FEF),
                            Color(0xFF5B4FDF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _currentPage == pages.length - 1 ? 'Get Started' : 'Next',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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


  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, animation, __) {
          return FadeTransition(opacity: animation, child: const LoginScreen());
        },
      ),
    );
  }
  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = min(140.0, constraints.maxWidth * 0.35);
        final isCompact = constraints.maxHeight < 700 || constraints.maxWidth < 380;
        final titleSize = isCompact ? 24.0 : 28.0;
        final descSize = isCompact ? 14.0 : 16.0;
        final verticalGap = isCompact ? 24.0 : 40.0;
        final horizontalPad = max(20.0, constraints.maxWidth * 0.08);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 16),
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page.description,
                        style: TextStyle(
                          fontSize: descSize,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                color: page.iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
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
                          height: 20 + (30 * sin(_waveController.value * 6.28 + (i * 0.4))).abs(),
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
                color: page.iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
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
                                height: 12 + (8 * sin(_sparkleController.value * 6.28)).abs(),
                                decoration: BoxDecoration(
                                  color: page.iconColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                width: 12,
                                height: 12 + (8 * sin(_sparkleController.value * 6.28 + 1.5)).abs(),
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
                color: page.iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating outer ring 1 (fast)
                    Transform.rotate(
                      angle: _rotateController.value * 4.0,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.iconColor.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Rotating outer ring 2 (medium speed, opposite)
                    Transform.rotate(
                      angle: -_rotateController.value * 2.5,
                      child: Container(
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.iconColor.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Real globe icon in the center
                    Icon(
                      Icons.public,
                      size: 50,
                      color: page.iconColor,
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
