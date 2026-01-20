import 'package:flutter/material.dart';

// Screens
import 'screens/splash/splash_screen.dart';
import 'screens/tutorial/tutorial1.dart';
import 'screens/tutorial/tutorial2.dart';
import 'screens/tutorial/tutorial3.dart';
import 'screens/authentication/login_screen.dart';
import 'screens/authentication/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/search_screen.dart';
import 'screens/home/voice_command_screen.dart';
import 'screens/home/settings_screen.dart';
import 'screens/home/mobiles_screen.dart';
import 'screens/home/laptops_screen.dart';
import 'screens/home/budget_deals_screen.dart';
import 'screens/home/ai_brands_screen.dart';
import 'screens/home/product_results_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Smart Product Recommender",
      debugShowCheckedModeBanner: false,

      // Theme (Light)
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),

      // Future Dark Theme Support
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),

      // 🚀 App starts from Splash
      initialRoute: "/",

      // ✅ Updated Routes with Tutorial Flow
      routes: {
        // Splash
        "/": (_) => SplashScreen(),

        // Tutorial / Onboarding
        "/tutorial1": (_) => const Tutorial1(),
        "/tutorial2": (_) => const Tutorial2(),
        "/tutorial3": (_) => const Tutorial3(),

        // Auth
        "/login": (_) => LoginScreen(),
        "/signup": (_) => SignupScreen(),

        // Home
        "/home": (_) => const HomeScreen(),
        "/voice-command": (_) => const VoiceCommandScreen(),
        "/settings": (_) => const SettingsScreen(),
        "/mobiles": (_) => const MobilesScreen(),
        "/laptops": (_) => const LaptopsScreen(),
        "/budget-deals": (_) => const BudgetDealsScreen(),
        "/ai-brands": (_) => const AIBrandsScreen(),
      },
    );
  }
}
