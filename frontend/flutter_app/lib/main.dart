import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

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

      // Initial route
      initialRoute: "/",

      // Named Routes for navigation
      routes: {
        "/": (_) => SplashScreen(),
        "/login": (_) => LoginScreen(),
        "/signup": (_) => SignupScreen(),
        "/home": (_) => HomeScreen(),
        // Will add later:
        // "/home": (_) => HomeScreen(),
        // "/search": (_) => SearchScreen(),
        // "/settings": (_) => SettingsScreen(),
      },
    );
  }
}
