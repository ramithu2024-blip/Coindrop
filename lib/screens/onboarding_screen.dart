import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../models/envelope.dart';
import '../services/security/auth_service.dart';
import '../providers/theme_provider.dart';
import '../providers/envelope_provider.dart';
import '../utils/currency.dart' show setCurrency;
import '../utils/envelope_icon_mapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  late final List<Widget> _pages;
  String? _pendingPin;
  bool _pendingBiometric = false;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _WelcomePage(),
      const _PainPointPage(),
      _ThemePage(onNext: _nextPage),
      _SecurityPage(onSavePin: _onSavePin),
      const _CurrencyPage(),
      _PaydaySetupPage(onNext: _nextPage),
      _StartingBalancePage(onNext: _nextPage),
      _EnvelopeSetupPage(onNext: _nextPage),
      _FinishPage(onFinish: _finishOnboarding),
    ];
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
    }
  }

  void _onSavePin(String pin, {bool biometric = false}) {
    _pendingPin = pin;
    _pendingBiometric = biometric;
    _nextPage();
  }

  Future<void> _finishOnboarding({bool tutorial = false}) async {
    if (_isFinishing) return;
    _isFinishing = true;
    final auth = context.read<AuthService>();
    if (_pendingPin == null) {
      if (!mounted) return;
      _isFinishing = false;
      setState(() => _currentPage = 3);
      return;
    }

    // Read prefs BEFORE setupPin (which may notifyListeners and unmount this widget)
    final prefs = await SharedPreferences.getInstance();
    final envelopeRaw = prefs.getString('onboarding_envelopes');

    if (!mounted) return;
    final ok = await auth.setupPin(_pendingPin!);
    if (!ok) {
      if (kDebugMode) debugPrint('[Onboarding] setupPin FAILED');
      _isFinishing = false;
      return;
    }

    // After setupPin, notifyListeners may have rebuilt the widget tree.
    // Use captured auth reference — do NOT call context.read or access context.
    if (_pendingBiometric) {
      await auth.storeBiometricKey();
    }

    if (!auth.dbHelper.isOpen) {
      if (kDebugMode) debugPrint('[Onboarding] DB not open — attempting reopen');
      try {
        final keyHex = await auth.deriveKeyHexFromPin(_pendingPin!);
        await auth.dbHelper.open(keyHex);
      } catch (e) {
        if (kDebugMode) debugPrint('[Onboarding] DB reopen failed: $e');
        _isFinishing = false;
        return;
      }
    }

    if (kDebugMode) debugPrint('[Onboarding] Creating recommended envelopes');
    try {
      await _createEnvelopesFromRaw(auth, envelopeRaw);
    } catch (e) {
      if (kDebugMode) debugPrint('[Onboarding] Envelope creation error (non-fatal): $e');
    }

    try {
      await auth.importPendingOnboardingPayday();
      await auth.importStartingBalance();
    } catch (e) {
      if (kDebugMode) debugPrint('[Onboarding] Import error (non-fatal): $e');
    }

    await prefs.setBool('onboarding_complete', true);

    // Refresh provider state so home screen shows envelopes immediately
    if (mounted) {
      try {
        await context.read<EnvelopeProvider>().loadEnvelopes();
      } catch (_) {}
    }

    // Navigation is only possible if widget is still mounted
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (tutorial) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const _TutorialScreen()),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  Future<void> _createEnvelopesFromRaw(AuthService auth, String? raw) async {
    if (raw == null || raw.isEmpty) {
      if (kDebugMode) debugPrint('[Onboarding] No envelopes to create');
      return;
    }
    final db = auth.dbHelper;
    if (!db.isOpen) {
      if (kDebugMode) debugPrint('[Onboarding] DB not open — skipping envelope creation');
      return;
    }
    final now = DateTime.now().toIso8601String();
    final names = raw.split(',');
    if (kDebugMode) debugPrint('[Onboarding] Creating ${names.length} envelopes: $names');

    // Batch all inserts atomically so the HomeScreen never sees
    // partial data when it calls loadEnvelopes() after the widget
    // tree rebuilds (triggered by auth.setupPin() → notifyListeners()).
    await Future.wait(names.where((n) => n.trim().isNotEmpty).map((name) {
      final trimmed = name.trim();
      final icon = EnvelopeIconMapper.iconKeyFor(trimmed);
      final color = EnvelopeIconMapper.colorFor(trimmed);
      return db.insertEnvelope(Envelope(
        name: trimmed,
        initialAmount: 0,
        createdAt: now,
        icon: icon,
        color: color,
      ));
    }));

    if (kDebugMode) debugPrint('[Onboarding] Recommended envelopes created successfully');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! < -100) {
                    _nextPage();
                  } else if (details.primaryVelocity! > 100 && _currentPage > 0) {
                    setState(() => _currentPage--);
                  }
                },
                child: IndexedStack(
                  index: _currentPage,
                  children: _pages,
                ),
              ),
            ),
            _buildIndicator(colors, _pages.length),
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

// ---------------------------------------------------------------------------
// 1. Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.account_balance_wallet_outlined, size: 40, color: colors.primary),
            ),
            const SizedBox(height: 32),
            Text(AppStrings.welcomeTitle,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            Text(AppStrings.welcomeSubtitle,
              style: TextStyle(fontSize: 15, color: textColor.withAlpha(150), height: 1.5),
              textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.findAncestorStateOfType<_OnboardingScreenState>()?._nextPage(),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(AppStrings.welcomeCta, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Pain Point — Choose your situation
// ---------------------------------------------------------------------------

class _PainPointPage extends StatefulWidget {
  const _PainPointPage();
  @override
  State<_PainPointPage> createState() => _PainPointPageState();
}

class _PainPointPageState extends State<_PainPointPage> {
  int _selectedIndex = -1;

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.psychology_outlined, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(AppStrings.painPointTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(AppStrings.painPointSubtitle,
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _PainPointOption(
                label: AppStrings.painPointSpend,
                isSelected: _selectedIndex == 0,
                onTap: () => _select(0),
                colors: colors,
                textColor: textColor,
              ),
              const SizedBox(height: 8),
              _PainPointOption(
                label: AppStrings.painPointConfusing,
                isSelected: _selectedIndex == 1,
                onTap: () => _select(1),
                colors: colors,
                textColor: textColor,
              ),
              const SizedBox(height: 8),
              _PainPointOption(
                label: AppStrings.painPointControl,
                isSelected: _selectedIndex == 2,
                onTap: () => _select(2),
                colors: colors,
                textColor: textColor,
              ),
              const SizedBox(height: 8),
              _PainPointOption(
                label: AppStrings.painPointCloud,
                isSelected: _selectedIndex == 3,
                onTap: () => _select(3),
                colors: colors,
                textColor: textColor,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.findAncestorStateOfType<_OnboardingScreenState>()?._nextPage(),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(AppStrings.painPointCta, style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PainPointOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colors;
  final Color textColor;

  const _PainPointOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withAlpha(18) : colors.onSurface.withAlpha(8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.primary : colors.onSurface.withAlpha(20),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              size: 16,
              color: isSelected ? colors.primary : colors.primary.withAlpha(120),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: TextStyle(
                  color: isSelected ? colors.primary : textColor,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Theme — Light/Dark/System + Accent color
// ---------------------------------------------------------------------------

class _ThemePage extends StatefulWidget {
  final VoidCallback onNext;
  const _ThemePage({required this.onNext});

  @override
  State<_ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<_ThemePage> {
  ThemeModeOption _option = ThemeModeOption.system;
  int _accentValue = 0xFF4CAF50;
  bool _cashAccent = true;
  bool _customColors = true;
  late final ThemeProvider _theme;

  @override
  void initState() {
    super.initState();
    _theme = context.read<ThemeProvider>();
    _option = _theme.themeModeOption;
    _accentValue = _theme.accentColorValue;
    _cashAccent = _theme.cashIconAccent;
    _customColors = _theme.useCustomEnvelopeColors;
  }

  void _setThemeMode(ThemeModeOption opt) {
    setState(() => _option = opt);
    _theme.setThemeMode(opt);
  }

  void _setAccent(int value) {
    setState(() => _accentValue = value);
    _theme.setAccentColor(value);
  }

  void _setCashAccent(bool v) {
    setState(() => _cashAccent = v);
    _theme.setCashIconAccent(v);
  }

  void _setCustomColors(bool v) {
    setState(() => _customColors = v);
    _theme.setUseCustomEnvelopeColors(v);
  }

  void _onContinue() {
    FocusScope.of(context).unfocus();
    widget.onNext();
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.palette_outlined, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(AppStrings.appearanceTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(AppStrings.appearanceSubtitle,
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: ThemeModeOption.values.map((opt) {
                  final selected = _option == opt;
                  return ChoiceChip(
                    label: Text(opt.label),
                    selected: selected,
                    onSelected: (_) => _setThemeMode(opt),
                    selectedColor: colors.primary.withAlpha(30),
                    backgroundColor: colors.onSurface.withAlpha(10),
                    labelStyle: TextStyle(
                      color: selected ? colors.primary : textColor.withAlpha(150),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected ? colors.primary : colors.onSurface.withAlpha(20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(AppStrings.appearanceAccent,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 12,
                alignment: WrapAlignment.center,
                children: AccentColorOption.all.map((opt) {
                  final selected = _accentValue == opt.value;
                  return GestureDetector(
                    onTap: () => _setAccent(opt.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: opt.color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: colors.onSurface, width: 3)
                            : Border.all(color: Colors.transparent),
                        boxShadow: selected
                            ? [BoxShadow(color: opt.color.withAlpha(100), blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(AppStrings.appearanceCashAccent,
                            style: TextStyle(fontSize: 14, color: textColor)),
                        ),
                        Switch(
                          value: _cashAccent,
                          onChanged: (v) => _setCashAccent(v),
                          activeColor: colors.primary,
                        ),
                      ],
                    ),
                    const Divider(height: 1, indent: 32),
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(AppStrings.appearanceCustomColors,
                            style: TextStyle(fontSize: 14, color: textColor)),
                        ),
                        Switch(
                          value: _customColors,
                          onChanged: (v) => _setCustomColors(v),
                          activeColor: colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(AppStrings.continueLabel, style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Security — PIN creation + optional biometric
// ---------------------------------------------------------------------------

class _SecurityPage extends StatefulWidget {
  final void Function(String pin, {bool biometric}) onSavePin;
  const _SecurityPage({required this.onSavePin});

  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  final _pinCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _pinFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _showConfirm = false;
  bool _biometricEnabled = false;
  bool _loading = false;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _biometricAvailable = auth.biometricAvailable;
  }

  @override
  void dispose() {
    _pinCtl.dispose();
    _confirmCtl.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;
    if (_pinCtl.text.length != 4) {
      setState(() => _error = AppStrings.pinErrorLength);
      return;
    }
    if (!_showConfirm) {
      setState(() { _showConfirm = true; _error = null; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirmFocus.requestFocus());
      return;
    }
    if (_pinCtl.text != _confirmCtl.text) {
      setState(() => _error = AppStrings.pinErrorMismatch);
      return;
    }
    setState(() { _loading = true; _error = null; });
    FocusScope.of(context).unfocus();
    if (_biometricAvailable && _biometricEnabled) {
      final auth = context.read<AuthService>();
      await auth.setBiometricUserEnabled(true);
    }
    widget.onSavePin(_pinCtl.text, biometric: _biometricAvailable && _biometricEnabled);
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.lock_outline, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                _showConfirm ? AppStrings.pinConfirmTitle : AppStrings.pinCreateTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                _showConfirm ? AppStrings.pinConfirmSubtitle : AppStrings.pinCreateSubtitle,
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
                    _PinField(
                      controller: _showConfirm ? _confirmCtl : _pinCtl,
                      focusNode: _showConfirm ? _confirmFocus : _pinFocus,
                      colors: colors,
                    ),
                    if (!_showConfirm && _biometricAvailable) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint, size: 20, color: _biometricEnabled ? colors.primary : colors.onSurface.withAlpha(80)),
                          const SizedBox(width: 8),
                          Text(AppStrings.pinBiometricLabel, style: TextStyle(color: textColor, fontSize: 14)),
                          const SizedBox(width: 8),
                          Switch(
                            value: _biometricEnabled,
                            activeColor: colors.primary,
                            onChanged: (v) => setState(() => _biometricEnabled = v),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _loading ? AppStrings.pinCtaLoading : (_showConfirm ? AppStrings.pinCtaConfirm : AppStrings.pinCtaInitial),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_showConfirm) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() { _showConfirm = false; _error = null; }),
                  child: Text(AppStrings.pinBack, style: TextStyle(color: colors.onSurface.withAlpha(120))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ColorScheme colors;

  const _PinField({
    required this.controller,
    required this.focusNode,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLength: 4,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(color: colors.onSurface, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: colors.onSurface.withAlpha(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.onSurface.withAlpha(25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.onSurface.withAlpha(25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Currency
// ---------------------------------------------------------------------------

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;

    const currencies = [
      ('en_AU', '\$', 'Australian Dollar (\$AUD)'),
      ('en_US', '\$', 'US Dollar (\$USD)'),
      ('en_GB', '£', 'British Pound (£GBP)'),
      ('de_DE', '€', 'Euro (€EUR)'),
    ];

    return _CurrencyPageBody(
      colors: colors,
      textColor: textColor,
      currencies: currencies,
    );
  }
}

class _CurrencyPageBody extends StatefulWidget {
  final ColorScheme colors;
  final Color textColor;
  final List<(String, String, String)> currencies;

  const _CurrencyPageBody({
    required this.colors,
    required this.textColor,
    required this.currencies,
  });

  @override
  State<_CurrencyPageBody> createState() => _CurrencyPageBodyState();
}

class _CurrencyPageBodyState extends State<_CurrencyPageBody> {
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
                  color: widget.colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.attach_money, size: 40, color: widget.colors.primary),
              ),
              const SizedBox(height: 32),
              Text(AppStrings.currencyTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.textColor)),
              const SizedBox(height: 8),
              Text(AppStrings.currencySubtitle,
                style: TextStyle(fontSize: 14, color: widget.textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...widget.currencies.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CurrencyOption(
                  locale: c.$1, symbol: c.$2, label: c.$3,
                  selected: _selectedLocale == c.$1,
                  colors: widget.colors, textColor: widget.textColor,
                  onTap: () => _select(c.$1, c.$2),
                ),
              )),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.findAncestorStateOfType<_OnboardingScreenState>()?._nextPage(),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.colors.primary,
                  foregroundColor: widget.colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(AppStrings.currencyCta, style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  final String locale, symbol, label;
  final bool selected;
  final ColorScheme colors;
  final Color textColor;
  final VoidCallback onTap;

  const _CurrencyOption({
    required this.locale, required this.symbol, required this.label,
    required this.selected, required this.colors, required this.textColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

// ---------------------------------------------------------------------------
// 6. Payday Setup — Yes/No + frequency + amount
// ---------------------------------------------------------------------------

class _PaydaySetupPage extends StatefulWidget {
  final VoidCallback onNext;

  const _PaydaySetupPage({required this.onNext});

  @override
  State<_PaydaySetupPage> createState() => _PaydaySetupPageState();
}

class _PaydaySetupPageState extends State<_PaydaySetupPage> {
  bool _hasPayday = false;
  final _amountCtl = TextEditingController();
  String _frequency = 'weekly';
  int _weekday = DateTime.monday;
  int _monthDay = 1;
  final _noteCtl = TextEditingController();
  final _customScheduleCtl = TextEditingController();

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    _customScheduleCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_hasPayday) {
      final amount = double.tryParse(_amountCtl.text);
      if (amount != null && amount > 0) {
        final prefs = await SharedPreferences.getInstance();
        if (_frequency == 'custom') {
          final data = '$amount|custom|0|${_customScheduleCtl.text}';
          await prefs.setString('onboarding_payday_setup', data);
        } else {
          final day = (_frequency == 'weekly' || _frequency == 'fortnightly') ? _weekday : _monthDay;
          final data = '$amount|$_frequency|$day|${_noteCtl.text}';
          await prefs.setString('onboarding_payday_setup', data);
        }
      }
    }
    widget.onNext();
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.payments_outlined, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(AppStrings.paydayTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChoiceChip(label: AppStrings.paydayYes, selected: _hasPayday, onTap: () => setState(() => _hasPayday = true), colors: colors, textColor: textColor),
                  const SizedBox(width: 12),
                  _ChoiceChip(label: AppStrings.paydayNo, selected: !_hasPayday, onTap: () => setState(() => _hasPayday = false), colors: colors, textColor: textColor),
                ],
              ),
              if (_hasPayday) ...[
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
                          hintText: AppStrings.paydayAmountHint,
                          hintStyle: TextStyle(color: textColor.withAlpha(60), fontSize: 28),
                          filled: true, fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _frequency,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: AppStrings.paydayFrequency,
                          labelStyle: TextStyle(color: textColor.withAlpha(120)),
                          filled: true, fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text(AppStrings.paydayWeekly)),
                          DropdownMenuItem(value: 'fortnightly', child: Text(AppStrings.paydayFortnightly)),
                          DropdownMenuItem(value: 'monthly', child: Text(AppStrings.paydayMonthly)),
                          DropdownMenuItem(value: 'custom', child: Text(AppStrings.paydayCustom)),
                        ],
                        onChanged: (v) => setState(() => _frequency = v!),
                      ),
                      const SizedBox(height: 12),
                      if (_frequency == 'weekly' || _frequency == 'fortnightly')
                        DropdownButtonFormField<int>(
                          value: _weekday.clamp(1, 7),
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: AppStrings.paydayDayOfWeek,
                            labelStyle: TextStyle(color: textColor.withAlpha(120)),
                            filled: true, fillColor: colors.surface,
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
                            labelText: AppStrings.paydayDayOfMonth,
                            labelStyle: TextStyle(color: textColor.withAlpha(120)),
                            filled: true, fillColor: colors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                          items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                          onChanged: (v) => setState(() => _monthDay = v!),
                        ),
                      if (_frequency == 'custom')
                        TextField(
                          controller: _customScheduleCtl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: AppStrings.paydayCustomHint,
                            hintStyle: TextStyle(color: textColor.withAlpha(80)),
                            filled: true, fillColor: colors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteCtl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: AppStrings.paydayNoteHint,
                          hintStyle: TextStyle(color: textColor.withAlpha(80)),
                          filled: true, fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(AppStrings.paydayCta, style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;
  final Color textColor;

  const _ChoiceChip({
    required this.label, required this.selected, required this.onTap,
    required this.colors, required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withAlpha(20) : colors.onSurface.withAlpha(8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.onSurface.withAlpha(20),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(label,
          style: TextStyle(
            color: selected ? colors.primary : textColor.withAlpha(150),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Starting Balance
// ---------------------------------------------------------------------------

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
    FocusScope.of(context).unfocus();
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
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.account_balance_wallet, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(AppStrings.balanceTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(AppStrings.balanceSubtitle,
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
                    hintText: AppStrings.balanceHint,
                    hintStyle: TextStyle(color: textColor.withAlpha(60), fontSize: 28),
                    filled: true, fillColor: colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(AppStrings.balanceFooter,
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
                    child: const Text(AppStrings.balanceSkip),
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
                    child: const Text(AppStrings.balanceSet, style: TextStyle(fontWeight: FontWeight.w600)),
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

// ---------------------------------------------------------------------------
// 8. Envelope Setup — Create own / Recommended
// ---------------------------------------------------------------------------

class _EnvelopeSetupPage extends StatefulWidget {
  final VoidCallback onNext;
  const _EnvelopeSetupPage({required this.onNext});

  @override
  State<_EnvelopeSetupPage> createState() => _EnvelopeSetupPageState();
}

class _EnvelopeSetupPageState extends State<_EnvelopeSetupPage> {
  bool _useRecommended = true;
  String _selectedTemplate = 'basic';
  String _customNames = '';

  static const _templates = [
    ('basic', AppStrings.envelopeTemplateBasic, ['Groceries', 'Bills', 'Transport', 'Savings', 'Fun']),
    ('student', AppStrings.envelopeTemplateStudent, ['Food', 'Transport', 'Study', 'Savings', 'Entertainment']),
    ('minimal', AppStrings.envelopeTemplateMinimal, ['Essentials', 'Bills', 'Savings']),
  ];

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    if (_useRecommended) {
      final template = _templates.firstWhere((t) => t.$1 == _selectedTemplate);
      await prefs.setString('onboarding_envelopes', template.$3.join(','));
      await prefs.setString('onboarding_envelope_template', _selectedTemplate);
    } else {
      if (_customNames.trim().isNotEmpty) {
        await prefs.setString('onboarding_envelopes', _customNames);
      }
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final template = _templates.firstWhere((t) => t.$1 == _selectedTemplate);

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
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.folder_outlined, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(AppStrings.envelopeTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(AppStrings.envelopeSubtitle,
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _ChoiceChip(label: AppStrings.envelopeRecommended, selected: _useRecommended,
                onTap: () => setState(() => _useRecommended = true), colors: colors, textColor: textColor),
              const SizedBox(height: 8),
              _ChoiceChip(label: AppStrings.envelopeCreateOwn, selected: !_useRecommended,
                onTap: () => setState(() => _useRecommended = false), colors: colors, textColor: textColor),
              if (_useRecommended) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedTemplate,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: AppStrings.envelopeTemplateLabel,
                      labelStyle: TextStyle(color: textColor.withAlpha(120)),
                      filled: true, fillColor: colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    items: _templates.map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2))
                    ).toList(),
                    onChanged: (v) => setState(() => _selectedTemplate = v!),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.envelopeListTitle, style: TextStyle(color: textColor.withAlpha(150), fontSize: 12)),
                      const SizedBox(height: 8),
                      ...(template.$3.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(n, style: TextStyle(color: textColor, fontSize: 14)),
                            const Spacer(),
                            Text('\$0', style: TextStyle(color: textColor.withAlpha(100), fontSize: 12)),
                          ],
                        ),
                      ))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(AppStrings.envelopeZeroFooter,
                  style: TextStyle(fontSize: 11, color: textColor.withAlpha(100), height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 16),
                TextField(
                  maxLines: 3,
                  controller: TextEditingController()..text = _customNames,
                  onChanged: (v) => _customNames = v,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: AppStrings.envelopeCustomHint,
                    hintStyle: TextStyle(color: textColor.withAlpha(80)),
                    filled: true, fillColor: colors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_useRecommended ? AppStrings.envelopeCtaRecommended : AppStrings.envelopeCtaSkip,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Finish — with built-in tutorial cards
// ---------------------------------------------------------------------------

class _FinishPage extends StatefulWidget {
  final void Function({bool tutorial}) onFinish;

  const _FinishPage({required this.onFinish});

  @override
  State<_FinishPage> createState() => _FinishPageState();
}

class _FinishPageState extends State<_FinishPage> {
  int _step = 0;

  static const _cards = [
    _TutorialCardData(
      icon: Icons.account_balance_wallet_outlined,
      title: AppStrings.tutorialStep0Title,
      description: AppStrings.tutorialStep0Body,
    ),
    _TutorialCardData(
      icon: Icons.auto_awesome_mosaic_outlined,
      title: AppStrings.tutorialStep1Title,
      description: AppStrings.tutorialStep1Body,
    ),
    _TutorialCardData(
      icon: Icons.add_circle_outline,
      title: AppStrings.tutorialStep2Title,
      description: AppStrings.tutorialStep2Body,
    ),
  ];

  void _next() {
    if (_step < _cards.length - 1) {
      setState(() => _step++);
    } else {
      widget.onFinish(tutorial: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = _cards[_step];

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
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(card.icon, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 32),
              Text(card.title,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 12),
              Text(card.description,
                style: TextStyle(fontSize: 15, color: colors.onSurface.withAlpha(150), height: 1.5),
                textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_cards.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _step ? 20 : 8, height: 8,
                    decoration: BoxDecoration(
                      color: i == _step ? colors.primary : colors.onSurface.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_step < _cards.length - 1 ? 'Next' : 'Go to Dashboard',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tutorial screen — shown after tapping "Quick Tutorial" on Finish page
// ---------------------------------------------------------------------------

class _TutorialScreen extends StatefulWidget {
  const _TutorialScreen();

  @override
  State<_TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<_TutorialScreen> {
  int _step = 0;

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cards = [
      _TutorialCardData(
        icon: Icons.account_balance_wallet_outlined,
        title: AppStrings.tutorialStep0Title,
        description: AppStrings.tutorialStep0Body,
      ),
      _TutorialCardData(
        icon: Icons.auto_awesome_mosaic_outlined,
        title: AppStrings.tutorialStep1Title,
        description: AppStrings.tutorialStep1Body,
      ),
      _TutorialCardData(
        icon: Icons.add_circle_outline,
        title: AppStrings.tutorialStep2Title,
        description: AppStrings.tutorialStep2Body,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(cards[_step].icon, size: 40, color: colors.primary),
                ),
                const SizedBox(height: 32),
                Text(cards[_step].title,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface)),
                const SizedBox(height: 12),
                Text(cards[_step].description,
                  style: TextStyle(fontSize: 15, color: colors.onSurface.withAlpha(150), height: 1.5),
                  textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(cards.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _step ? 20 : 8, height: 8,
                      decoration: BoxDecoration(
                        color: i == _step ? colors.primary : colors.onSurface.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_step < 2 ? AppStrings.tutorialNext : AppStrings.tutorialFinish,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialCardData {
  final IconData icon;
  final String title;
  final String description;
  const _TutorialCardData({required this.icon, required this.title, required this.description});
}
