import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _currentDot = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();

    // Animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // Dots animation
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _currentDot = (_currentDot + 1) % 3;
      });
    });

    // Navigate to next page
    Timer(const Duration(seconds: 5), () {
      _dotTimer?.cancel();
      Navigator.pushReplacementNamed(context, "/home");
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Container
                  Container(
                    width: width * 0.28,
                    height: width * 0.28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.search,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "FYNDO",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    width: width * 0.55,
                    height: 2,
                    color: Colors.white,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Find Your Way",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentDot == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
