import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  int _activeDot = 0;
  Timer? _dotTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _initAnimations();
    _startDotAnimation();
    _navigateNext();
  }

  void _initAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scale = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _activeDot = (_activeDot + 1) % 3);
    });
  }

  void _navigateNext() {
    _navigationTimer = Timer(const Duration(seconds: 4), () {
      _dotTimer?.cancel();
      Navigator.pushReplacementNamed(context, "/tutorial1");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotTimer?.cancel();
    _navigationTimer?.cancel();
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
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _logo(width),
                  const SizedBox(height: 30),
                  _title(),
                  const SizedBox(height: 10),
                  _divider(width),
                  const SizedBox(height: 16),
                  _tagline(),
                  const SizedBox(height: 40),
                  _dots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= UI PARTS =================

  Widget _logo(double width) {
    return Container(
      width: width * 0.28,
      height: width * 0.28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.search, size: 50, color: Colors.white),
    );
  }

  Widget _title() {
    return const Text(
      "FYNDO",
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 8,
      ),
    );
  }

  Widget _divider(double width) {
    return Container(width: width * 0.55, height: 2, color: Colors.white);
  }

  Widget _tagline() {
    return const Text(
      "Find Your Way",
      style: TextStyle(fontSize: 16, color: Colors.white, letterSpacing: 1),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _activeDot == index
                ? Colors.white
                : Colors.white.withOpacity(0.4),
          ),
        );
      }),
    );
  }
}
