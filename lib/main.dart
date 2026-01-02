import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/expense_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/privacy_consent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const GroupXpenseApp());
}

class GroupXpenseApp extends StatelessWidget {
  const GroupXpenseApp({super.key});

  Future<bool> _hasAcceptedPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('privacy_accepted') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Group Xpense',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                primary: Colors.teal,
                secondary: Colors.cyan,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.grey[100],

              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              tabBarTheme: const TabBarThemeData(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.cyan,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),

              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),

              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.white,
                elevation: 4,
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),

              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),

              chipTheme: ChipThemeData(
                backgroundColor: Colors.teal[50],
                selectedColor: Colors.teal,
                labelStyle: const TextStyle(color: Colors.teal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              dividerTheme: DividerThemeData(
                color: Colors.grey[300],
                thickness: 1,
                space: 1,
              ),

              useMaterial3: true,
            ),
            home: FutureBuilder<bool>(
              future: _hasAcceptedPrivacy(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final hasAccepted = snapshot.data ?? false;

                if (!hasAccepted) {
                  return const PrivacyConsentScreen();
                }

                return settingsProvider.settings.biometricEnabled
                    ? const BiometricLockScreen()
                    : const HomeScreen();
              },
            ),
          );
        },
      ),
    );
  }
}