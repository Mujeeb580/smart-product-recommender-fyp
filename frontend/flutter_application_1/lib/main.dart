import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/enhanced_chat_screen.dart';
import 'features/home/profile_screen.dart';
import 'features/products/product_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FYNDO',
      theme: AppTheme.lightTheme(),
      home: const SplashScreen(),
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signUp: (context) => const SignUpScreen(),
        AppRoutes.home: (context) => const _MainScreen(),
        AppRoutes.chat: (context) => const EnhancedChatScreen(),
        AppRoutes.productList: (context) => const ProductListScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
      },
    );
  }
}

// Main screen with bottom navigation
class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    EnhancedChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
