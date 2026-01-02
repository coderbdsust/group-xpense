import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/currency_service.dart';
import '../services/biometric_service.dart';
import '../utils/privacy_policy.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SecuritySection(),
          const Divider(height: 32),
          _CurrencySection(),
          const Divider(height: 32),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final settings = settingsProvider.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Security',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        FutureBuilder<bool>(
          future: BiometricService.isAvailable(),
          builder: (context, snapshot) {
            final isAvailable = snapshot.data ?? false;

            return SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: Colors.teal),
              title: const Text('Biometric Authentication'),
              subtitle: Text(
                isAvailable
                    ? 'Secure your app with fingerprint or face recognition'
                    : 'Not available on this device',
              ),
              value: settings.biometricEnabled,
              activeColor: Colors.teal,
              onChanged: isAvailable
                  ? (value) async {
                try {
                  await settingsProvider.toggleBiometric(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Biometric authentication enabled'
                              : 'Biometric authentication disabled',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
                  : null,
            );
          },
        ),
        if (settings.biometricEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'App will require authentication on launch',
                      style: TextStyle(color: Colors.green[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrencySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final settings = settingsProvider.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Currency',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.attach_money, color: Colors.teal),
          title: const Text('Default Currency'),
          subtitle: Text(
            '${CurrencyService.getCurrencyName(settings.currency)} (${settings.currencySymbol})',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _showCurrencyPicker(context, settingsProvider);
          },
        ),
      ],
    );
  }

  void _showCurrencyPicker(
      BuildContext context,
      SettingsProvider provider,
      ) {
    final currencies = CurrencyService.getAllCurrencies();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Currency',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected =
                      currency['code'] == provider.settings.currency;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      isSelected ? Colors.teal : Colors.grey[200],
                      child: Text(
                        currency['symbol']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(currency['name']!),
                    subtitle: Text('${currency['code']} (${currency['symbol']})'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.teal)
                        : null,
                    onTap: () async {
                      await provider.setCurrency(
                        currency['code']!,
                        currency['symbol']!,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Currency changed to ${currency['name']}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.teal),
          title: const Text('Version'),
          subtitle: const Text('2.1.0'),
        ),
        ListTile(
          leading: const Icon(Icons.code, color: Colors.teal),
          title: const Text('Developer'),
          subtitle: const Text('Built with Flutter'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip, color: Colors.teal),
          title: const Text('Privacy Policy'),
          subtitle: Text('Version ${PrivacyPolicy.version}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.security, color: Colors.teal),
          title: const Text('Privacy'),
          subtitle: const Text('All data stored locally on your device'),
        ),
      ],
    );
  }
}