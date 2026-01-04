import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';
import '../services/biometric_service.dart';
import '../utils/app_constants.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_settings');

    if (settingsJson != null) {
      _settings = AppSettings.fromJson(json.decode(settingsJson));
      notifyListeners();
    }
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', json.encode(_settings.toJson()));
    notifyListeners();
  }

  Future<void> toggleBiometric(bool enabled) async {
    if (enabled) {
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        throw Exception(
          'Biometric authentication not available on this device',
        );
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Enable biometric authentication for ${AppConstants.appName}',
      );

      if (!authenticated) {
        throw Exception('Authentication failed');
      }
    }

    _settings = _settings.copyWith(biometricEnabled: enabled);
    await saveSettings();
  }

  Future<void> setCurrency(String currencyCode, String symbol) async {
    _settings = _settings.copyWith(
      currency: currencyCode,
      currencySymbol: symbol,
    );
    await saveSettings();
  }
}
