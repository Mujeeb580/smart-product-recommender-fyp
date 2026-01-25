import 'package:flutter/material.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String productList = '/products';
  static const String productDetail = '/product/:id';
  static const String profile = '/profile';

  // Navigator for easy navigation
  static void navigateTo(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  static void navigateAndRemove(BuildContext context, String route) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(route, (Route<dynamic> route) => false);
  }

  static void pop(BuildContext context) {
    Navigator.of(context).pop();
  }

  static void popUntil(BuildContext context, String route) {
    Navigator.of(context).popUntil(ModalRoute.withName(route));
  }
}
