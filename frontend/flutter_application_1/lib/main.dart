
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'services/theme_provider.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/chat_screen.dart';
import 'features/home/profile_screen.dart';
import 'features/products/product_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('ur'),
        Locale('ar'),
        Locale('fr'),
        Locale('de'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FYNDO',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SplashScreen(),
          routes: {
            AppRoutes.splash: (context) => const SplashScreen(),
            AppRoutes.onboarding: (context) => const OnboardingScreen(),
            AppRoutes.login: (context) => const LoginScreen(),
            AppRoutes.signUp: (context) => const SignUpScreen(),
            AppRoutes.home: (context) => const _MainScreen(),
            AppRoutes.chat: (context) => const ChatScreen(),
            AppRoutes.productList: (context) => const ProductListScreen(),
            AppRoutes.profile: (context) => const ProfileScreen(),
          },
        );
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

  List<Widget> get _screens => [
        const HomeScreen(),
        ChatScreen(onBackPressed: () {
          setState(() {
            _selectedIndex = 0;
          });
        }),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      extendBody: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E).withOpacity(0.9),
                        const Color(0xFF16213E).withOpacity(0.9),
                      ]
                    : [
                        const Color(0xFF7C3AED).withOpacity(0.85),
                        const Color(0xFF6D28D9).withOpacity(0.85),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.white,
              unselectedItemColor:
                  isDark ? Colors.white54 : Colors.white.withOpacity(0.6),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
