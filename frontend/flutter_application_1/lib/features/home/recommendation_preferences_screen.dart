import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/recommendation_preferences_service.dart';
import '../../services/theme_provider.dart';

class RecommendationPreferencesScreen extends StatefulWidget {
  const RecommendationPreferencesScreen({super.key});

  @override
  State<RecommendationPreferencesScreen> createState() =>
      _RecommendationPreferencesScreenState();
}

class _RecommendationPreferencesScreenState
    extends State<RecommendationPreferencesScreen> {
  final _service = RecommendationPreferencesService();
  final _budgetController = TextEditingController();
  String _category = 'any';
  String _priority = 'balanced';
  bool _seniorFriendly = false;
  bool _voiceAutoSend = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await _service.load();
    if (!mounted) return;
    setState(() {
      _category = value.category;
      _priority = value.priority;
      _budgetController.text = value.budget?.toString() ?? '';
      _seniorFriendly = value.seniorFriendly;
      _voiceAutoSend = value.voiceAutoSend;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final budgetText = _budgetController.text.replaceAll(',', '').trim();
    final budget = budgetText.isEmpty ? null : int.tryParse(budgetText);
    if (budgetText.isNotEmpty && (budget == null || budget <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid budget greater than zero.')),
      );
      return;
    }
    setState(() => _saving = true);
    await _service.save(
      RecommendationPreferences(
        category: _category,
        priority: _priority,
        budget: budget,
        seniorFriendly: _seniorFriendly,
        voiceAutoSend: _voiceAutoSend,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recommendation preferences saved.')),
    );
  }

  Future<void> _reset() async {
    await _service.reset();
    if (!mounted) return;
    setState(() {
      _category = 'any';
      _priority = 'balanced';
      _budgetController.clear();
      _seniorFriendly = false;
      _voiceAutoSend = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferences reset to defaults.')),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = context.watch<ThemeProvider>().currentGradient;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Shopping Preferences',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save what matters to you, then use it as a one-tap request in chat.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78)),
                    ),
                    const SizedBox(height: 20),
                    _PreferenceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('Preferred category'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: _decoration('Choose a category'),
                            style: theme.textTheme.bodyLarge,
                            items: const [
                              DropdownMenuItem(
                                  value: 'any',
                                  child: Text('Phones or laptops')),
                              DropdownMenuItem(
                                  value: 'phones', child: Text('Phones')),
                              DropdownMenuItem(
                                  value: 'laptops', child: Text('Laptops')),
                            ],
                            onChanged: (value) =>
                                setState(() => _category = value ?? 'any'),
                          ),
                          const SizedBox(height: 16),
                          const _Label('Maximum budget (PKR)'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            style: theme.textTheme.bodyLarge,
                            decoration: _decoration('Example: 50000'),
                          ),
                          const SizedBox(height: 16),
                          const _Label('Main priority'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: _decoration('Choose a priority'),
                            style: theme.textTheme.bodyLarge,
                            items: const [
                              DropdownMenuItem(
                                  value: 'balanced',
                                  child: Text('Balanced use')),
                              DropdownMenuItem(
                                  value: 'value', child: Text('Best value')),
                              DropdownMenuItem(
                                  value: 'battery',
                                  child: Text('Battery life')),
                              DropdownMenuItem(
                                  value: 'camera',
                                  child: Text('Camera quality')),
                              DropdownMenuItem(
                                  value: 'performance',
                                  child: Text('Performance')),
                            ],
                            onChanged: (value) =>
                                setState(() => _priority = value ?? 'balanced'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PreferenceCard(
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title:
                                const Text('Senior-friendly recommendations'),
                            subtitle: const Text(
                                'Prefer simple, practical options for calling and social media.'),
                            value: _seniorFriendly,
                            onChanged: (value) =>
                                setState(() => _seniorFriendly = value),
                          ),
                          Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.black.withValues(alpha: 0.12),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                                'Send voice transcript automatically'),
                            subtitle: const Text(
                                'Turn off to review and edit speech-to-text before sending.'),
                            value: _voiceAutoSend,
                            onChanged: (value) =>
                                setState(() => _voiceAutoSend = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save preferences'),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _reset,
                      child: const Text(
                        'Reset to defaults',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.14);
    return InputDecoration(
      hintText: hint,
      hintStyle: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      filled: true,
      fillColor: isDark
          ? const Color(0xFF111827).withValues(alpha: 0.82)
          : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  final Widget child;
  const _PreferenceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF151A2F).withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.50),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}
