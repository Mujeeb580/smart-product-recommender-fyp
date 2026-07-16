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
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'New password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Include a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include a number';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      await AuthService().changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF0F766E), Color(0xFF0E7490), Color(0xFF38BDF8)];

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                      Text(
                        'Change Password',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
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
                          _PasswordField(
                            controller: _currentController,
                            hint: 'Enter current password',
                            obscure: _obscureCurrent,
                            onToggleVisibility: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Current password is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          const _FieldLabel(text: 'New password'),
                          const SizedBox(height: 8),
                          _PasswordField(
                            controller: _newController,
                            hint: 'Enter new password',
                            obscure: _obscureNew,
                            onChanged: (_) => setState(() {}),
                            onToggleVisibility: () => setState(
                              () => _obscureNew = !_obscureNew,
                            ),
                            validator: _validateNewPassword,
                          ),
                          const SizedBox(height: 14),
                          const _FieldLabel(text: 'Confirm password'),
                          const SizedBox(height: 8),
                          _PasswordField(
                            controller: _confirmController,
                            hint: 'Confirm new password',
                            obscure: _obscureConfirm,
                            onToggleVisibility: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            validator: (value) => value != _newController.text
                                ? 'Passwords do not match'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          _StrengthMeter(password: _newController.text),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: const Icon(Icons.lock_reset),
                              label: Text(
                                _isSubmitting
                                    ? 'Updating...'
                                    : 'Update Password',
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
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final String password;
  const _StrengthMeter({required this.password});

  double get strength {
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    return score / 4;
  }

  @override
  Widget build(BuildContext context) {
    final label =
        strength >= 1 ? 'Strong' : (strength >= .5 ? 'Medium' : 'Weak');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password strength', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: Colors.white24,
          color: strength >= 1 ? Colors.greenAccent : Colors.amberAccent,
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _GlassFormCard extends StatelessWidget {
  final Widget child;
  const _GlassFormCard({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final String? Function(String?) validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.validator,
    required this.onToggleVisibility,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          suffixIcon: IconButton(
            tooltip: obscure ? 'Show password' : 'Hide password',
            onPressed: onToggleVisibility,
            icon: Icon(
              obscure ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white),
          ),
          errorStyle: const TextStyle(color: Color(0xFFFFCDD2)),
        ),
      );
}
