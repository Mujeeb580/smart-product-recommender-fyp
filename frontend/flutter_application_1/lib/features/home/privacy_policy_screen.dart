import 'dart:ui';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)]
        : const [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF93C5FD)];

    final sections = const [
      _PolicySection(
        title: 'Overview',
        body:
            'We respect your privacy and keep your data protected. This policy explains what we collect and how it is used in FYNDO.',
      ),
      _PolicySection(
        title: 'Information We Collect',
        body:
            'We may collect basic account details, device information, and usage analytics to improve recommendations.',
      ),
      _PolicySection(
        title: 'How We Use Data',
        body:
            'Your data helps personalize results, improve app performance, and provide relevant product suggestions.',
      ),
      _PolicySection(
        title: 'Security',
        body:
            'We use industry-standard security measures and never sell your personal information to third parties.',
      ),
      _PolicySection(
        title: 'Your Choices',
        body:
            'You can update your preferences, opt out of notifications, or request data removal at any time.',
      ),
      _PolicySection(
        title: 'Contact Us',
        body:
            'If you have any questions about privacy, reach out to our support team from the Help & Support screen.',
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                      'Privacy Policy',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const _GlassIconButton(icon: Icons.privacy_tip_outlined),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return _GlassSectionCard(
                      title: section.title,
                      body: section.body,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection {
  final String title;
  final String body;
  const _PolicySection({required this.title, required this.body});
}

class _GlassSectionCard extends StatelessWidget {
  final String title;
  final String body;

  const _GlassSectionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                    fontSize: 13,
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
