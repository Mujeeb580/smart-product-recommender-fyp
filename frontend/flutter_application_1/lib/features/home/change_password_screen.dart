import 'dart:ui';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController
      ..removeListener(_onPasswordChanged)
      ..dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated'),
          duration: Duration(seconds: 2),
        ),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF93C5FD)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const _GlassIconButton(
                                icon: Icons.arrow_back_ios_new,
                              ),
                            ),
                            Text(
                              'Change Password',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const _GlassIconButton(icon: Icons.lock_outline),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _GlassFormCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(text: 'Current password'),
                                const SizedBox(height: 8),
                                _GlassTextField(
                                  controller: _currentPasswordController,
                                  hint: '••••••••',
                                  obscure: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Current password is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                const _FieldLabel(text: 'New password'),
                                const SizedBox(height: 8),
                                _GlassTextField(
                                  controller: _newPasswordController,
                                  hint: '••••••••',
                                  obscure: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'New password is required';
                                    }
                                    if (value.length < 8) {
                                      return 'Use at least 8 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                const _FieldLabel(text: 'Confirm password'),
                                const SizedBox(height: 8),
                                _GlassTextField(
                                  controller: _confirmPasswordController,
                                  hint: '••••••••',
                                  obscure: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                _StrengthMeter(password: _newPasswordController.text),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                          ),
                                        ),
                                        child: TextButton.icon(
                                          onPressed: _isSaving
                                              ? null
                                              : _updatePassword,
                                          icon: _isSaving
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.check_circle,
                                                  color: Colors.white),
                                          label: Text(
                                            _isSaving
                                                ? 'Updating...'
                                                : 'Update Password',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final String password;

  const _StrengthMeter({required this.password});

  @override
  Widget build(BuildContext context) {
    final length = password.length;
    final score = length >= 12
        ? 1.0
        : length >= 8
            ? 0.7
            : length >= 6
                ? 0.45
                : 0.15;
    final label = length >= 12
        ? 'Strong'
        : length >= 8
            ? 'Good'
            : length >= 6
                ? 'Weak'
                : 'Very weak';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password strength',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: score,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassFormCard extends StatelessWidget {
  final Widget child;
  const _GlassFormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.85),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _GlassTextField({
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  const _GlassIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
