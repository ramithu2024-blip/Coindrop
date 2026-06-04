import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/envelope_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/add_envelope_screen.dart';
import 'screens/envelope_detail_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/expired_screen.dart';
import 'screens/payday_allocation_screen.dart';
import 'screens/alloc_percentages_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_screen.dart';
import 'services/security/auth_service.dart';
import 'services/security/build_gate_service.dart';
import 'services/security/trial_gate_service.dart';
import 'widgets/hidden_unlock_detector.dart';

class CoinDropApp extends StatelessWidget {
  const CoinDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthService>(
      builder: (context, themeProvider, auth, _) {
        final accent = themeProvider.accentColor;

        Widget app = MaterialApp(
          key: const ValueKey('coinDropApp'),
          title: 'CoinDrop',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: _buildTheme(accent, Brightness.light),
          darkTheme: _buildTheme(accent, Brightness.dark),
          home: const _AppGateWidget(),
          onGenerateRoute: _onGenerateRoute,
        );

        // Wrap in hidden unlock detector so the 7-tap sequence works
        // even when the app is in expiredLocked state.
        app = HiddenUnlockDetector(child: app);

        // Provide EnvelopeProvider above the Navigator so all routes
        // (including pushNamed routes like /settings) can access it.
        if (auth.initialized && auth.isAuthenticated) {
          app = ChangeNotifierProvider<EnvelopeProvider>(
            create: (_) => EnvelopeProvider(auth),
            child: app,
          );
        }

        return app;
      },
    );
  }

  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case '/':
        page = const _AppGateWidget();
        break;
      case '/add-envelope':
        page = const AddEnvelopeScreen();
        break;
      case '/envelope-detail':
        page = const EnvelopeDetailScreen();
        break;
      case '/add-transaction':
        page = const AddTransactionScreen();
        break;
      case '/payday-allocate':
        page = const PaydayAllocationScreen();
        break;
      case '/alloc-percentages':
        page = const AllocPercentagesScreen();
        break;
      case '/settings':
        page = const SettingsScreen();
        break;
      case '/security':
        page = const SecurityScreen();
        break;
      default:
        page = const _AppGateWidget();
    }

    return _buildPageRoute(page, settings);
  }

  static PageRouteBuilder _buildPageRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  static ThemeData _buildTheme(Color accent, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final surfaceContainer = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final popupSurface = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        secondary: accent,
        surface: surface,
        onPrimary: isDark ? Colors.black : Colors.white,
        onSecondary: isDark ? Colors.black : Colors.white,
        onSurface: textColor,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: isDark ? Colors.black : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainer,
        contentTextStyle: TextStyle(color: textColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: popupSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: TextStyle(color: textColor, fontSize: 14),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(popupSurface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: subtextColor.withAlpha(50)),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(popupSurface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        labelStyle: TextStyle(color: subtextColor),
        hintStyle: TextStyle(color: subtextColor.withAlpha(150)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
      ),
    );
  }
}

class _AppGateWidget extends StatefulWidget {
  const _AppGateWidget();

  @override
  State<_AppGateWidget> createState() => _AppGateWidgetState();
}

class _AppGateWidgetState extends State<_AppGateWidget> {
  bool _attemptedBiometric = false;

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthService, BuildGateService, TrialGateService>(
      builder: (context, auth, gate, trial, _) {
        if (!auth.initialized || !gate.initialized || !trial.initialized) {
          return const _SplashScreen();
        }
        // Build gate check: expired and not unlocked
        if (gate.state == AppLockState.expiredLocked) {
          return const ExpiredScreen();
        }
        // Trial gate check: expired and not unlocked
        if (trial.state == TrialState.expired) {
          return ExpiredScreen(
            title: 'Your 7-day trial has ended',
            message: 'Export your data or enter a license code to continue',
            showUnlockField: true,
            onUnlock: (code) => context.read<TrialGateService>().attemptUnlock(code),
          );
        }
        if (!auth.hasVault) {
          return const OnboardingScreen();
        }
        if (!auth.isAuthenticated) {
          if (!_attemptedBiometric) {
            _attemptedBiometric = true;
            _tryBiometricUnlock(auth);
          }
          return const PinScreen(mode: PinMode.unlock);
        }
        return const HomeScreen();
      },
    );
  }

  Future<void> _tryBiometricUnlock(AuthService auth) async {
    final canUse = await auth.canUnlockWithBiometrics();
    if (!canUse || !mounted) return;
    await auth.unlockWithBiometrics();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance, size: 64, color: colors.primary),
            const SizedBox(height: 24),
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
