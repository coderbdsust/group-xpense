import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';

class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final int decimalDigits;

  const CurrencyText({
    super.key,
    required this.amount,
    this.style,
    this.decimalDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;

    return Text(
      NumberFormat.currency(
        symbol: settings.currencySymbol,
        decimalDigits: decimalDigits,
      ).format(amount),
      style: style,
    );
  }
}
