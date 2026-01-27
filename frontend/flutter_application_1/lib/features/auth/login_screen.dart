import 'dart:ui';

import 'package:flutter/material.dart';
import '../../widgets/glassy_shine.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscure = true;
  bool _isDarkMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Min 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least 1 number';
    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    // Navigate to home on successful login
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _goToSignUp() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const SignUpScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors = _isDarkMode
        ? [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF93C5FD)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth.clamp(320.0, 500.0);
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withOpacity(0.12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 20,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 22,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _isDarkMode = !_isDarkMode;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                _isDarkMode
                                                    ? Icons.light_mode
                                                    : Icons.dark_mode,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: _goToSignUp,
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Sign up'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Welcome back to FYNDO',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      TextFormField(
                                        controller: _emailController,
                                        style: const TextStyle(
                                            color: Colors.black),
                                        cursorColor: Colors.black,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor:
                                              Colors.white.withOpacity(0.9),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 20,
                                          ),
                                          labelText: 'Email',
                                          labelStyle: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.never,
                                          hintText: 'Enter your email',
                                          hintStyle: const TextStyle(
                                            color: Colors.black38,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.mail,
                                            color: Colors.black54,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Colors.black54,
                                              width: 1.2,
                                            ),
                                          ),
                                          errorStyle: const TextStyle(
                                            color: Color(0xFFFF4D4F),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFF4D4F),
                                              width: 1.2,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFF4D4F),
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: _validateEmail,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        style: const TextStyle(
                                            color: Colors.black),
                                        cursorColor: Colors.black,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor:
                                              Colors.white.withOpacity(0.9),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 20,
                                          ),
                                          labelText: 'Password',
                                          labelStyle: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.never,
                                          hintText: 'Enter your password',
                                          hintStyle: const TextStyle(
                                            color: Colors.black38,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.lock,
                                            color: Colors.black54,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscure
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscure = !_obscure,
                                            ),
                                            color: Colors.black54,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Colors.black54,
                                              width: 1.2,
                                            ),
                                          ),
                                          errorStyle: const TextStyle(
                                            color: Color(0xFFFF4D4F),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFF4D4F),
                                              width: 1.2,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFF4D4F),
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                        obscureText: _obscure,
                                        validator: _validatePassword,
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Forgot password coming soon',
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Forgot password?',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed:
                                            _isSubmitting ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isDarkMode
                                              ? Colors.grey.shade800
                                              : const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: _isDarkMode
                                                ? BorderSide(
                                                    color: Colors.grey.shade600,
                                                    width: 1,
                                                  )
                                                : BorderSide.none,
                                          ),
                                          elevation: _isDarkMode ? 2 : 4,
                                          shadowColor: _isDarkMode
                                              ? Colors.black.withOpacity(0.5)
                                              : const Color(0xFF6366F1)
                                                  .withOpacity(0.3),
                                        ),
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Login',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            "Don't have an account?",
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                          TextButton(
                                            onPressed: _goToSignUp,
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Sign up'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const GlassyShine(),
          ],
        ),
      ),
    );
  }
}
