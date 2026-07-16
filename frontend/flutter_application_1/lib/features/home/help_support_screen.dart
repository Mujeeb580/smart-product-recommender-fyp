import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  bool _openingEmail = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _openingEmail = true);
    final body = [
      'Name: ${_name.text.trim()}',
      'Email: ${_email.text.trim()}',
      if (_phone.text.trim().isNotEmpty) 'Phone: ${_phone.text.trim()}',
      '',
      _description.text.trim(),
    ].join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@fyndo.com',
      queryParameters: {
        'subject': 'FYNDO support request',
        'body': body,
      },
    );
    try {
      final opened = await launchUrl(uri);
      if (!mounted) return;
      setState(() => _openingEmail = false);
      if (opened) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app is available on this device.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open an email app on this device.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF0F766E), Color(0xFF0E7490), Color(0xFF38BDF8)];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Help & Support',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const Icon(Icons.support_agent, color: Colors.white, size: 72),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white.withOpacity(.12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _field(
                              controller: _name,
                              label: 'Your name',
                              validator: (value) =>
                                  value == null || value.trim().length < 2
                                      ? 'Enter your name'
                                      : null,
                            ),
                            _field(
                              controller: _email,
                              label: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(text)
                                    ? null
                                    : 'Enter a valid email';
                              },
                            ),
                            _field(
                              controller: _phone,
                              label: 'Phone number (optional)',
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) return null;
                                return RegExp(r'^\+?[0-9 ()-]{7,20}$')
                                        .hasMatch(text)
                                    ? null
                                    : 'Enter a valid phone number';
                              },
                            ),
                            _field(
                              controller: _description,
                              label: 'Problem description',
                              maxLines: 4,
                              validator: (value) => value == null ||
                                      value.trim().length < 10
                                  ? 'Describe the issue in at least 10 characters'
                                  : null,
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openingEmail ? null : _submit,
                                icon: const Icon(Icons.email_outlined),
                                label: Text(
                                  _openingEmail
                                      ? 'Opening email...'
                                      : 'Email Support',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.chat),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Ask the AI Assistant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
            errorStyle: const TextStyle(color: Color(0xFFFFCDD2)),
            filled: true,
            fillColor: Colors.white.withOpacity(.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
