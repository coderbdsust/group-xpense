class AppSettings {
  final bool biometricEnabled;
  final String currency;
  final String currencySymbol;

  AppSettings({
    this.biometricEnabled = false,
    this.currency = 'USD',
    this.currencySymbol = '\$',
  });

  AppSettings copyWith({
    bool? biometricEnabled,
    String? currency,
    String? currencySymbol,
  }) {
    return AppSettings(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biometricEnabled': biometricEnabled,
      'currency': currency,
      'currencySymbol': currencySymbol,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      biometricEnabled: json['biometricEnabled'] ?? false,
      currency: json['currency'] ?? 'USD',
      currencySymbol: json['currencySymbol'] ?? '\$',
    );
  }
}
