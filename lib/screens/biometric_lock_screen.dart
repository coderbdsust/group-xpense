import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';
import 'home_screen.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  bool _isAuthenticating = false;
  String _message = 'Authenticate to continue';
  bool _canRetry = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay authentication slightly to ensure screen is fully built
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _authenticate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-authenticate when app comes to foreground
    if (state == AppLifecycleState.resumed && !_isAuthenticating) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _message = 'Authenticating...';
      _canRetry = true;
    });

    try {
      // Check if biometric is available
      final isAvailable = await BiometricService.isAvailable();

      if (!isAvailable) {
        setState(() {
          _message = 'Biometric authentication not available';
          _isAuthenticating = false;
          _canRetry = true;
        });

        // Show error and bypass authentication
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _navigateToHome();
        }
        return;
      }

      // Get available biometrics for display
      final biometrics = await BiometricService.getAvailableBiometrics();
      final biometricType = BiometricService.getBiometricTypeString(biometrics);

      setState(() {
        _message = 'Authenticate with $biometricType';
      });

      // Attempt authentication
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to access Group Xpense',
      );

      if (authenticated && mounted) {
        _navigateToHome();
      } else {
        setState(() {
          _isAuthenticating = false;
          _message = 'Authentication failed. Try again.';
          _canRetry = true;
        });
      }
    } catch (e) {
      print('Authentication error: $e');
      setState(() {
        _isAuthenticating = false;
        _message = 'Error: ${e.toString()}';
        _canRetry = true;
      });
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _skipAuthentication() {
    // Optional: Add a way to skip authentication in development
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Authentication'),
        content: const Text(
          'Are you sure you want to skip biometric authentication?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              _navigateToHome();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isAuthenticating ? Icons.fingerprint : Icons.lock,
                size: 100,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(height: 32),
              Text(
                'Group Xpense',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              if (_isAuthenticating)
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              else if (_canRetry)
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Authenticate'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _skipAuthentication,
                      child: Text(
                        'Skip (Development Only)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
