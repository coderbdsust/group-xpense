import 'package:flutter/material.dart';
import 'package:group_xpense/utils/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_policy_screen.dart';
import 'home_screen.dart';

class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _acceptedPrivacy = false;
  bool _acceptedTerms = false;
  bool _understand = false;

  @override
  Widget build(BuildContext context) {
    final allAccepted = _acceptedPrivacy && _acceptedTerms && _understand;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // App Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // App Name
              const Text(
                'Welcome to ${AppConstants.appName}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              Text(
                'Your Privacy Matters',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 40),

              // Privacy highlights
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _PrivacyHighlight(
                        icon: Icons.phone_android,
                        title: 'Local Storage Only',
                        description:
                            'All your data stays on your device. No cloud storage.',
                      ),
                      const SizedBox(height: 16),
                      _PrivacyHighlight(
                        icon: Icons.security,
                        title: 'Complete Privacy',
                        description:
                            'No data sharing, no tracking, no advertisements.',
                      ),
                      const SizedBox(height: 16),
                      _PrivacyHighlight(
                        icon: Icons.lock,
                        title: 'Your Control',
                        description:
                            'Delete your data anytime by uninstalling the app.',
                      ),
                      const SizedBox(height: 32),

                      // Consent checkboxes
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: _acceptedPrivacy,
                              activeColor: Colors.teal,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedPrivacy = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'I have read and accept the ',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PrivacyPolicyScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 24),
                            CheckboxListTile(
                              value: _acceptedTerms,
                              activeColor: Colors.teal,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'I agree to the Terms of Service',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            const Divider(height: 24),
                            CheckboxListTile(
                              value: _understand,
                              activeColor: Colors.teal,
                              onChanged: (value) {
                                setState(() {
                                  _understand = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'I understand that all data is stored locally and will be deleted if I uninstall the app',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Continue button
              FilledButton(
                onPressed: allAccepted ? _acceptAndContinue : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: allAccepted ? Colors.teal : Colors.grey[300],
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 16),

              // Version info
              Text(
                'Privacy Policy Version ${AppConstants.privacyPolicyVersion}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    await prefs.setString('privacy_version', AppConstants.privacyPolicyVersion);
    await prefs.setString(
      'privacy_accepted_date',
      DateTime.now().toIso8601String(),
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}

class _PrivacyHighlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PrivacyHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
