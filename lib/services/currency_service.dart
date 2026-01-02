class CurrencyService {
  static final Map<String, Map<String, String>> currencies = {
    'USD': {'name': 'US Dollar', 'symbol': '\$', 'code': 'USD'},
    'EUR': {'name': 'Euro', 'symbol': '€', 'code': 'EUR'},
    'GBP': {'name': 'British Pound', 'symbol': '£', 'code': 'GBP'},
    'JPY': {'name': 'Japanese Yen', 'symbol': '¥', 'code': 'JPY'},
    'CNY': {'name': 'Chinese Yuan', 'symbol': '¥', 'code': 'CNY'},
    'INR': {'name': 'Indian Rupee', 'symbol': '₹', 'code': 'INR'},
    'AUD': {'name': 'Australian Dollar', 'symbol': 'A\$', 'code': 'AUD'},
    'CAD': {'name': 'Canadian Dollar', 'symbol': 'C\$', 'code': 'CAD'},
    'CHF': {'name': 'Swiss Franc', 'symbol': 'CHF', 'code': 'CHF'},
    'BDT': {'name': 'Bangladeshi Taka', 'symbol': '৳', 'code': 'BDT'},
    'AED': {'name': 'UAE Dirham', 'symbol': 'د.إ', 'code': 'AED'},
    'SGD': {'name': 'Singapore Dollar', 'symbol': 'S\$', 'code': 'SGD'},
    'MYR': {'name': 'Malaysian Ringgit', 'symbol': 'RM', 'code': 'MYR'},
    'THB': {'name': 'Thai Baht', 'symbol': '฿', 'code': 'THB'},
    'KRW': {'name': 'South Korean Won', 'symbol': '₩', 'code': 'KRW'},
  };

  static String getCurrencySymbol(String code) {
    return currencies[code]?['symbol'] ?? '\$';
  }

  static String getCurrencyName(String code) {
    return currencies[code]?['name'] ?? 'US Dollar';
  }

  static List<Map<String, String>> getAllCurrencies() {
    return currencies.entries
        .map(
          (e) => {
            'code': e.key,
            'name': e.value['name']!,
            'symbol': e.value['symbol']!,
          },
        )
        .toList();
  }
}
