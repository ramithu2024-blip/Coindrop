import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/security/auth_service.dart';
import '../widgets/color_picker/color_picker_dialog.dart';
import 'pin_screen.dart';
import '../utils/currency.dart' show setCurrency;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    final auth = context.read<AuthService>();
    setState(() => _biometricAvailable = auth.biometricAvailable);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<Widget> get _pages => [
        _WelcomePage(onNext: _nextPage),
        _ThemePage(onNext: _nextPage),
        _CurrencyPage(onNext: _nextPage),
        if (_biometricAvailable)
          _BiometricsPage(onNext: _nextPage),
        _PaydaySetupPage(onNext: _nextPage),
        _StartingBalancePage(onNext: _nextPage),
        _BudgetModePage(onNext: _nextPage),
        _FinishPage(
          onStart: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const PinScreen(mode: PinMode.setup),
              ),
            );
          },
        ),
      ];

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pageList = _pages;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: pageList,
              ),
            ),
            _buildIndicator(colors, pageList.length),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(ColorScheme colors, int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _currentPage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _currentPage ? colors.primary : colors.onSurface.withAlpha(30),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary.withAlpha(60), colors.primary.withAlpha(20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.primary.withAlpha(40)),
                ),
                child: Icon(Icons.account_balance_wallet, size: 50, color: colors.primary),
              ),
              const SizedBox(height: 40),
              Text(
                'Welcome to CoinDrop',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Take control of your finances with digital cash envelopes.\n'
                'Your data stays on your device — fully encrypted.',
                style: TextStyle(
                  fontSize: 15,
                  color: textColor.withAlpha(150),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary.withAlpha(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'End-to-end encrypted with SQLCipher.\nYour PIN is your key.',
                        style: TextStyle(color: colors.primary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePage extends StatelessWidget {
  final VoidCallback onNext;

  const _ThemePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final textColor = colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.palette_outlined, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Choose Your Style',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick an accent color that suits you.\nYou can change it later in Settings.',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withAlpha(150),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ...AccentColorOption.all.map((option) {
                    final isSelected = option.value == themeProvider.accentColorValue;
                    return GestureDetector(
                      onTap: () => themeProvider.setAccentColor(option.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: option.color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: colors.onSurface, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: option.color.withAlpha(100), blurRadius: 12, spreadRadius: 2)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () async {
                      final color = await showColorPicker(
                        context,
                        initialColor: themeProvider.accentColor,
                      );
                      if (color != null) {
                        themeProvider.setAccentColor(color.value);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeProvider.accentOption.isCustom
                              ? colors.onSurface
                              : colors.onSurface.withAlpha(80),
                          width: themeProvider.accentOption.isCustom ? 3 : 2,
                        ),
                        gradient: themeProvider.accentOption.isCustom
                            ? null
                            : const SweepGradient(
                                colors: [
                                  Color(0xFFFF0000),
                                  Color(0xFFFF8800),
                                  Color(0xFFFFFF00),
                                  Color(0xFF00FF00),
                                  Color(0xFF0088FF),
                                  Color(0xFF8800FF),
                                  Color(0xFFFF0000),
                                ],
                              ),
                        color: themeProvider.accentOption.isCustom
                            ? themeProvider.accentColor
                            : null,
                        boxShadow: themeProvider.accentOption.isCustom
                            ? [BoxShadow(color: themeProvider.accentColor.withAlpha(100), blurRadius: 12, spreadRadius: 2)]
                            : null,
                      ),
                      child: themeProvider.accentOption.isCustom
                          ? const Icon(Icons.check, color: Colors.white, size: 22)
                          : Icon(Icons.colorize, size: 20, color: Colors.white.withAlpha(180)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments, size: 20,
                      color: themeProvider.cashIconAccent ? themeProvider.accentColor : colors.onSurface.withAlpha(120)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Color cash icon with accent', style: TextStyle(
                        color: colors.onSurface, fontSize: 13,
                      )),
                    ),
                    Switch(
                      value: themeProvider.cashIconAccent,
                      activeColor: colors.primary,
                      onChanged: (v) => themeProvider.setCashIconAccent(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ...ThemeModeOption.values.map((option) {
                      final selected = option == themeProvider.themeModeOption;
                      return InkWell(
                        onTap: () => themeProvider.setThemeMode(option),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                option == ThemeModeOption.dark ? Icons.dark_mode :
                                option == ThemeModeOption.light ? Icons.light_mode :
                                option == ThemeModeOption.system ? Icons.settings_brightness :
                                Icons.schedule,
                                size: 20,
                                color: selected ? colors.primary : textColor.withAlpha(120),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                option.label,
                                style: TextStyle(
                                  color: selected ? colors.primary : textColor,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              if (selected)
                                Icon(Icons.check_circle, size: 20, color: colors.primary),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyPage extends StatefulWidget {
  final VoidCallback onNext;

  const _CurrencyPage({required this.onNext});

  @override
  State<_CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<_CurrencyPage> {
  String _selectedLocale = 'en_AU';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString('currency_locale') ?? 'en_AU';
    if (mounted) setState(() { _selectedLocale = locale; });
  }

  Future<void> _select(String locale, String symbol) async {
    await setCurrency(locale, symbol);
    setState(() { _selectedLocale = locale; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final themeProvider = context.watch<ThemeProvider>();
    final iconColor = themeProvider.cashIconAccent ? themeProvider.accentColor : colors.onSurface.withAlpha(120);

    final currencies = [
      ('en_AU', '\$', 'Australian Dollar (\$AUD)'),
      ('en_US', '\$', 'US Dollar (\$USD)'),
      ('en_GB', '£', 'British Pound (£GBP)'),
      ('de_DE', '€', 'Euro (€EUR)'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.attach_money, size: 40, color: iconColor),
              ),
              const SizedBox(height: 32),
              Text('Choose Currency', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text('Select your preferred currency format.',
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...currencies.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCurrencyOption(c.$1, c.$2, c.$3, colors, textColor),
              )),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(String locale, String symbol, String label, ColorScheme colors, Color textColor) {
    final selected = _selectedLocale == locale;
    return GestureDetector(
      onTap: () => _select(locale, symbol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withAlpha(20) : colors.onSurface.withAlpha(8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.onSurface.withAlpha(20), width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(symbol, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14))),
            if (selected) Icon(Icons.check_circle, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BudgetModePage extends StatefulWidget {
  final VoidCallback onNext;

  const _BudgetModePage({required this.onNext});

  @override
  State<_BudgetModePage> createState() => _BudgetModePageState();
}

class _BudgetModePageState extends State<_BudgetModePage> {
  String _selectedMode = 'manual';

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_divide_enabled', _selectedMode != 'manual');
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final themeProvider = context.watch<ThemeProvider>();
    final iconColor = themeProvider.cashIconAccent ? themeProvider.accentColor : colors.onSurface.withAlpha(120);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.account_balance, size: 40, color: iconColor),
              ),
              const SizedBox(height: 32),
              Text('Budgeting Mode', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text('Choose how you want to manage your money.',
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _ModeCard(
                icon: Icons.touch_app, title: 'Manual', description: 'You decide how much goes into each envelope. Full control.',
                selected: _selectedMode == 'manual', colors: colors, textColor: textColor,
                onTap: () => setState(() => _selectedMode = 'manual'),
              ),
              const SizedBox(height: 8),
              _ModeCard(
                icon: Icons.auto_graph, title: 'Auto (Percentage Split)',
                description: 'Paydays are automatically split across envelopes by saved percentages.',
                selected: _selectedMode == 'auto', colors: colors, textColor: textColor,
                onTap: () => setState(() => _selectedMode = 'auto'),
              ),
              const SizedBox(height: 8),
              _ModeCard(
                icon: Icons.swap_horiz, title: 'Hybrid',
                description: 'Auto-allocate by default, but you can manually adjust anytime.',
                selected: _selectedMode == 'hybrid', colors: colors, textColor: textColor,
                onTap: () => setState(() => _selectedMode = 'hybrid'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saveAndContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_selectedMode == 'manual' ? 'Continue (Manual)' : 'Continue (Auto)',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final ColorScheme colors;
  final Color textColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon, required this.title, required this.description,
    required this.selected, required this.colors, required this.textColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withAlpha(20) : colors.onSurface.withAlpha(8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.primary : colors.onSurface.withAlpha(20),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? colors.primary : colors.onSurface.withAlpha(120), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(fontSize: 12, color: textColor.withAlpha(120))),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _FinishPage extends StatelessWidget {
  final VoidCallback onStart;

  const _FinishPage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary.withAlpha(60), colors.primary.withAlpha(20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.primary.withAlpha(40)),
                ),
                child: Icon(Icons.lock_outline, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Secure Your Vault',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your financial data will be encrypted with a PIN.\n'
                'This PIN is the only way to unlock your vault.\n'
                'There is no password recovery — keep it safe.',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withAlpha(150),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Write down your PIN. If you forget it,\nyour data cannot be recovered.',
                        style: TextStyle(color: Colors.amber.shade700, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.lock_open),
                label: const Text('Set Up PIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(220, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricsPage extends StatefulWidget {
  final VoidCallback onNext;

  const _BiometricsPage({required this.onNext});

  @override
  State<_BiometricsPage> createState() => _BiometricsPageState();
}

class _BiometricsPageState extends State<_BiometricsPage> {
  bool _biometricEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final enabled = await auth.getBiometricUserEnabled();
    if (mounted) setState(() { _biometricEnabled = enabled; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.fingerprint, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Biometric Unlock',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              Text(
                'Use your fingerprint to quickly unlock\nthe app without entering your PIN.',
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint, color: _biometricEnabled ? colors.primary : colors.onSurface.withAlpha(60)),
                    const SizedBox(width: 12),
                    Text('Fingerprint unlock', style: TextStyle(color: textColor, fontSize: 15)),
                    const SizedBox(width: 12),
                    _loading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                        : Switch(
                            value: _biometricEnabled,
                            activeColor: colors.primary,
                            onChanged: (v) async {
                              setState(() => _biometricEnabled = v);
                              await context.read<AuthService>().setBiometricUserEnabled(v);
                            },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your fingerprint data never leaves your device.\n'
                'You can change this anytime in Security settings.',
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(100), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: widget.onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaydaySetupPage extends StatefulWidget {
  final VoidCallback onNext;

  const _PaydaySetupPage({required this.onNext});

  @override
  State<_PaydaySetupPage> createState() => _PaydaySetupPageState();
}

class _PaydaySetupPageState extends State<_PaydaySetupPage> {
  final _amountCtl = TextEditingController();
  String _frequency = 'weekly';
  int _weekday = DateTime.monday;
  int _monthDay = 1;
  final _noteCtl = TextEditingController();

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final themeProvider = context.watch<ThemeProvider>();
    final iconColor = themeProvider.cashIconAccent ? themeProvider.accentColor : colors.onSurface.withAlpha(120);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.payments_outlined, size: 40, color: iconColor),
              ),
              const SizedBox(height: 32),
              Text(
                'Set Up Your Pay',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Optionally add a recurring paycheck.\nYou can configure this later in Settings.',
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _amountCtl,
                      style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: textColor.withAlpha(60), fontSize: 28),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Frequency',
                        labelStyle: TextStyle(color: textColor.withAlpha(120)),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'fortnightly', child: Text('Fortnightly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_frequency == 'weekly' || _frequency == 'fortnightly')
                      DropdownButtonFormField<int>(
                        value: _weekday.clamp(1, 7),
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Day of Week',
                          labelStyle: TextStyle(color: textColor.withAlpha(120)),
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Monday')),
                          DropdownMenuItem(value: 2, child: Text('Tuesday')),
                          DropdownMenuItem(value: 3, child: Text('Wednesday')),
                          DropdownMenuItem(value: 4, child: Text('Thursday')),
                          DropdownMenuItem(value: 5, child: Text('Friday')),
                          DropdownMenuItem(value: 6, child: Text('Saturday')),
                          DropdownMenuItem(value: 7, child: Text('Sunday')),
                        ],
                        onChanged: (v) => setState(() => _weekday = v!),
                      ),
                    if (_frequency == 'monthly')
                      DropdownButtonFormField<int>(
                        value: _monthDay.clamp(1, 28),
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Day of Month',
                          labelStyle: TextStyle(color: textColor.withAlpha(120)),
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                        onChanged: (v) => setState(() => _monthDay = v!),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Paycheck note (optional)',
                        hintStyle: TextStyle(color: textColor.withAlpha(80)),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _saveAndContinue(skip: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface.withAlpha(120),
                      side: BorderSide(color: colors.onSurface.withAlpha(30)),
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => _saveAndContinue(skip: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: const Size(160, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndContinue({required bool skip}) async {
    if (!skip) {
      final amount = double.tryParse(_amountCtl.text);
      if (amount != null && amount > 0) {
        final day = (_frequency == 'weekly' || _frequency == 'fortnightly') ? _weekday : _monthDay;
        final data = '$amount|$_frequency|$day|${_noteCtl.text}';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onboarding_payday_setup', data);
        if (kDebugMode) debugPrint('[Onboarding] Saved pending payday: $data');
      }
    }
    widget.onNext();
  }
}

class _StartingBalancePage extends StatefulWidget {
  final VoidCallback onNext;

  const _StartingBalancePage({required this.onNext});

  @override
  State<_StartingBalancePage> createState() => _StartingBalancePageState();
}

class _StartingBalancePageState extends State<_StartingBalancePage> {
  final _amountCtl = TextEditingController();

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool skip}) async {
    if (!skip) {
      final amount = double.tryParse(_amountCtl.text);
      if (amount != null && amount > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('onboarding_starting_balance', amount);
      }
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final themeProvider = context.watch<ThemeProvider>();
    final iconColor = themeProvider.cashIconAccent ? themeProvider.accentColor : colors.onSurface.withAlpha(120);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.account_balance_wallet, size: 40, color: iconColor),
              ),
              const SizedBox(height: 32),
              Text(
                'Starting Balance',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the money you already have,\nor start fresh with \$0.',
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _amountCtl,
                  style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: textColor.withAlpha(60), fontSize: 28),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is added once as your opening balance.\nYou can always add more after setup.',
                style: TextStyle(fontSize: 11, color: textColor.withAlpha(100), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _save(skip: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface.withAlpha(120),
                      side: BorderSide(color: colors.onSurface.withAlpha(30)),
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Start Fresh'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => _save(skip: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: const Size(160, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Set Balance', style: TextStyle(fontWeight: FontWeight.w600)),
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
