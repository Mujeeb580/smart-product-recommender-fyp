import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lightMode = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "settings",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the row
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Settings Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Appearance Section
                        Text(
                          "APPEARANCE",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildSwitchTile(
                          icon: Icons.wb_sunny_outlined,
                          title: "Light mode",
                          subtitle: "Activate light theme",
                          value: _lightMode,
                          onChanged: (val) {
                            setState(() {
                              _lightMode = val;
                              if (val) _darkMode = false;
                            });
                          },
                        ),

                        const SizedBox(height: 12),

                        _buildSwitchTile(
                          icon: Icons.dark_mode_outlined,
                          title: "Dark mode",
                          subtitle: "Activate dark theme",
                          value: _darkMode,
                          onChanged: (val) {
                            setState(() {
                              _darkMode = val;
                              if (val) _lightMode = false;
                            });
                          },
                        ),

                        const SizedBox(height: 32),

                        // Language & Location Section
                        Text(
                          "LANGUAGE & LOCATION",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildNavigationTile(
                          icon: Icons.language,
                          title: "Language",
                          subtitle: "English",
                          onTap: () {
                            // Navigate to language selection
                          },
                        ),

                        const SizedBox(height: 12),

                        _buildNavigationTile(
                          icon: Icons.location_on_outlined,
                          title: "Region",
                          subtitle: "Pakistan",
                          onTap: () {
                            // Navigate to region selection
                          },
                        ),

                        const SizedBox(height: 32),

                        // Voice & Search Section
                        Text(
                          "VOICE & SEARCH",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildNavigationTile(
                          icon: Icons.settings_voice_outlined,
                          title: "Voice & Audio Settings",
                          subtitle: "Configure voice commands",
                          onTap: () {
                            // Navigate to voice settings
                          },
                        ),

                        const SizedBox(height: 32),

                        // Price & Results Section
                        Text(
                          "PRICE & RESULTS",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildNavigationTile(
                          icon: Icons.attach_money_outlined,
                          title: "Data & Privacy Settings",
                          subtitle: "Manage your data",
                          onTap: () {
                            // Navigate to privacy settings
                          },
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
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF7C3AED), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF7C3AED), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
