import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _wipeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _wipeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation for logo and text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    // Wipe animation for background transition
    _wipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _wipeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wipeController, curve: Curves.easeInOutCubic),
    );

    _fadeController.forward();

    // Start wipe animation after 1.5 seconds
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _wipeController.forward();
      }
    });

    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    // Start restoring Firebase's persisted mobile session while the splash
    // animation is playing. Firebase keeps the user signed in across restarts.
    final sessionCheck = AuthService().isLoggedIn();
    final adminSessionCheck = AdminService().hasValidSession();

    await Future<void>.delayed(const Duration(seconds: 3));
    final isAdminSignedIn = await adminSessionCheck;
    final isSignedIn = await sessionCheck;

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      isAdminSignedIn
          ? AppRoutes.admin
          : isSignedIn
              ? AppRoutes.home
              : AppRoutes.onboarding,
      (route) => false,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _wipeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _wipeAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Gradient background - ocean teal to sky blue
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F766E), // Ocean teal
                      Color(0xFF0E7490), // Deep cyan
                      Color(0xFF93C5FD), // Light blue
                    ],
                  ),
                ),
              ),
              // Black wipe overlay from left with curve
              ClipPath(
                clipper: _CurvedWipeClipper(
                  progress: _wipeAnimation.value,
                  fromLeft: true,
                ),
                child: Container(
                  width: screenWidth,
                  height: screenHeight,
                  color: Colors.black,
                ),
              ),
              // Black wipe overlay from right with curve
              ClipPath(
                clipper: _CurvedWipeClipper(
                  progress: _wipeAnimation.value,
                  fromLeft: false,
                ),
                child: Container(
                  width: screenWidth,
                  height: screenHeight,
                  color: Colors.black,
                ),
              ),
              // Content
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'lib/assets/images/logo.png',
                        width: 280,
                        height: 280,
                      ),
                      const SizedBox(height: 8),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF00E5CC),
                            Color(0xFF00D9C5),
                            Color(0xFF00CCC0),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          "FYNDO",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2),
                                blurRadius: 4,
                                color: Color.fromARGB(60, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _wipeAnimation,
                        builder: (context, child) {
                          return Text(
                            "Find Your Next Deal Online",
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2.0,
                              color: _wipeAnimation.value > 0.5
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black54,
                              fontWeight: FontWeight.w300,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurvedWipeClipper extends CustomClipper<Path> {
  final double progress;
  final bool fromLeft;

  _CurvedWipeClipper({required this.progress, required this.fromLeft});

  @override
  Path getClip(Size size) {
    final path = Path();
    final curveWidth = size.width * progress / 2;
    final curveDepth = 150.0; // Depth of the curve

    if (fromLeft) {
      if (progress > 0.0) {
        path.moveTo(0, 0);
        path.lineTo(curveWidth, 0);

        // Create a smooth flowing curve on the right edge
        final controlX = curveWidth + curveDepth;
        path.quadraticBezierTo(
          controlX,
          size.height / 2,
          curveWidth,
          size.height,
        );

        path.lineTo(0, size.height);
        path.close();
      }
    } else {
      if (progress > 0.0) {
        path.moveTo(size.width, 0);
        path.lineTo(size.width - curveWidth, 0);

        // Create a smooth flowing curve on the left edge
        final controlX = size.width - curveWidth - curveDepth;
        path.quadraticBezierTo(
          controlX,
          size.height / 2,
          size.width - curveWidth,
          size.height,
        );

        path.lineTo(size.width, size.height);
        path.close();
      }
    }

    return path;
  }

  @override
  bool shouldReclip(_CurvedWipeClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
