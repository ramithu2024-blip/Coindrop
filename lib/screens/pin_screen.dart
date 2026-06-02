import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/pin_input_widget.dart';
import '../services/security/auth_service.dart';

enum PinMode { setup, unlock }

class PinScreen extends StatefulWidget {
  final PinMode mode;

  const PinScreen({super.key, required this.mode});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  late FocusNode _pinFocus;
  late FocusNode _confirmFocus;
  bool _showConfirm = false;
  bool _error = false;
  String _errorMsg = '';
  bool _loading = false;
  bool _isProcessing = false;
  String _loadingText = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _biometricAvailable = false;
  bool _canUseBiometrics = false;
  int _pinLength = 0;
  int _confirmLength = 0;
  int _lockoutRemaining = 0;
  Timer? _lockoutTimer;
  bool _vaultWiped = false;

  @override
  void initState() {
    super.initState();
    _pinFocus = FocusNode();
    _confirmFocus = FocusNode();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _pinController.addListener(_onPinChanged);
    _confirmController.addListener(_onConfirmChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkState();
    });
  }

  void _onPinChanged() {
    setState(() => _pinLength = _pinController.text.length);
    if (_error && !_showConfirm) {
      setState(() => _error = false);
    }
  }

  void _onConfirmChanged() {
    setState(() => _confirmLength = _confirmController.text.length);
    if (_error) {
      setState(() => _error = false);
    }
  }

  Future<void> _checkState() async {
    if (widget.mode != PinMode.unlock) return;
    final auth = context.read<AuthService>();
    final canUse = await auth.canUnlockWithBiometrics();

    if (mounted) {
      setState(() {
        _biometricAvailable = auth.biometricAvailable;
        _canUseBiometrics = canUse;
        if (auth.vaultWiped) {
          _vaultWiped = true;
        }
      });
    }

    _updateLockout(auth);
  }

  void _updateLockout(AuthService auth) {
    if (auth.isLockedOut) {
      _lockoutRemaining = auth.lockoutRemainingSeconds;
      if (mounted) setState(() {});
      _lockoutTimer?.cancel();
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final auth = context.read<AuthService>();
        if (!mounted || !auth.isLockedOut) {
          _lockoutTimer?.cancel();
          if (mounted) setState(() => _lockoutRemaining = 0);
          return;
        }
        setState(() => _lockoutRemaining = auth.lockoutRemainingSeconds);
      });
    } else {
      _lockoutRemaining = 0;
      _lockoutTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _pinController.removeListener(_onPinChanged);
    _confirmController.removeListener(_onConfirmChanged);
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLock = widget.mode == PinMode.unlock;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),

                  if (_vaultWiped)
                    _buildWipeContent(colors)
                  else ...[
                    AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary.withAlpha(40),
                            colors.primary.withAlpha(15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.primary.withAlpha(30),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isLock
                            ? (_error ? Icons.lock_outline : Icons.lock)
                            : (_showConfirm ? Icons.lock_outline : Icons.lock_open),
                        size: 38,
                        color: _error ? colors.error : colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    isLock ? 'Vault Locked' : (_showConfirm ? 'Confirm PIN' : 'Set Vault PIN'),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLock
                        ? 'Enter your PIN to access your vault'
                        : (_showConfirm ? 'Re-enter your PIN to confirm' : 'Create a 4-digit PIN to protect your vault'),
                    style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 14),
                  ),

                  // -- Lockout Countdown --
                  if (_lockoutRemaining > 0 && isLock) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.error.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_off_outlined, size: 18, color: colors.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Too many failed attempts. Try again in ${_formatDuration(_lockoutRemaining)}.',
                              style: TextStyle(color: colors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),
                  _buildPinRow(colors, _pinController, _pinFocus, _pinLength, false),
                  if (_showConfirm && !isLock) ...[
                    const SizedBox(height: 20),
                    _buildPinRow(colors, _confirmController, _confirmFocus, _confirmLength, true),
                  ],
                  if (_error) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.error.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: colors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg,
                              style: TextStyle(color: colors.error, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final shake = _shakeAnimation.value;
                      final offset = sin(shake * pi * 6) * 6;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: (_loading || _isProcessing || _lockoutRemaining > 0)
                            ? null
                            : (isLock ? _verifyPin : _setupPin),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          isLock
                              ? 'Unlock Vault'
                              : (_showConfirm ? 'Confirm' : 'Continue'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  if (isLock && _biometricAvailable && _canUseBiometrics) ...[
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: (_lockoutRemaining > 0) ? null : _authenticateBiometric,
                      icon: Icon(Icons.fingerprint, size: 22, color: colors.primary),
                      label: Text(
                        'Unlock with Fingerprint',
                        style: TextStyle(color: colors.primary, fontSize: 15),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_loading)
            IgnorePointer(
              child: Container(
                color: colors.surface.withAlpha(230),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.onSurface.withAlpha(20),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 36, height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                        Text(_loadingText,
                          style: TextStyle(color: colors.onSurface, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWipeContent(ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: colors.error.withAlpha(20),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.delete_forever_outlined, size: 42, color: colors.error),
        ),
        const SizedBox(height: 24),
        Text('Vault Wiped',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface),
        ),
        const SizedBox(height: 12),
        Text(
          '10 incorrect PIN attempts.\nYour encrypted vault has been permanently deleted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurface.withAlpha(150), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startSetup,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: const Text('Start Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Backup restore coming soon'), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.restore, size: 20),
            label: const Text('Restore Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Future<void> _startSetup() async {
    final auth = context.read<AuthService>();
    await auth.destroyVault();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  String _formatDuration(int seconds) {
    if (seconds >= 60) {
      return '${seconds ~/ 60}m ${seconds % 60}s';
    }
    return '${seconds}s';
  }

  Widget _buildPinRow(ColorScheme colors, TextEditingController controller,
      FocusNode focusNode, int length, bool isConfirm) {
    return PinInputWidget(
      controller: controller,
      focusNode: focusNode,
      length: length,
      error: _error,
      disabled: _lockoutRemaining > 0,
      colors: colors,
    );
  }

  Future<void> _authenticateBiometric() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final auth = context.read<AuthService>();
      final success = await auth.unlockWithBiometrics();
      if (!mounted) return;
      if (success) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/');
          });
        }
      } else {
        setState(() {
          _error = true;
          _errorMsg = 'Biometric authentication failed';
        });
        _triggerShake();
      }
    } catch (_) {}
    _isProcessing = false;
  }

  Future<void> _verifyPin() async {
    if (_isProcessing) return;
    final auth = context.read<AuthService>();
    if (auth.isLockedOut) {
      setState(() {
        _error = true;
        _errorMsg = 'Too many failed attempts. Please wait.';
      });
      return;
    }
    if (_pinController.text.length != 4) {
      setState(() { _error = true; _errorMsg = 'PIN must be 4 digits'; });
      _triggerShake();
      return;
    }
    _isProcessing = true;
    setState(() { _loading = true; _loadingText = 'Verifying PIN...'; });
    try {
      final isValid = await auth.verifyPin(_pinController.text);
      if (!mounted) return;
      if (isValid) {
        await _tryStoreBiometricKey();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/');
          });
      } else if (auth.vaultWiped) {
        setState(() {
          _vaultWiped = true;
          _error = false;
          _loading = false;
        });
      } else if (auth.isLockedOut) {
        setState(() {
          _error = true;
          _errorMsg = 'Too many failed attempts. Try again later.';
          _loading = false;
        });
        _isProcessing = false;
        _updateLockout(auth);
      } else {
        _isProcessing = false;
        setState(() { _error = true; _errorMsg = 'Incorrect PIN'; _loading = false; });
        _triggerShake();
        _updateLockout(auth);
      }
    } catch (_) {
      _isProcessing = false;
      if (mounted) {
        setState(() { _error = true; _errorMsg = 'Verification failed'; _loading = false; });
      }
    }
  }

  Future<void> _tryStoreBiometricKey() async {
    final auth = context.read<AuthService>();
    if (!auth.biometricAvailable) return;
    if (!await auth.getBiometricUserEnabled()) return;
    await auth.storeBiometricKey();
  }

  Future<void> _setupPin() async {
    if (_isProcessing) return;
    if (_pinController.text.length != 4) {
      setState(() { _error = true; _errorMsg = 'PIN must be 4 digits'; });
      _triggerShake();
      return;
    }
    if (!_showConfirm) {
      setState(() { _showConfirm = true; _error = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmFocus.requestFocus();
      });
      return;
    }
    if (_pinController.text != _confirmController.text) {
      setState(() { _error = true; _errorMsg = 'PIN entries do not match'; });
      _triggerShake();
      return;
    }
    setState(() { _loading = true; _loadingText = 'Securing vault...'; });
    _isProcessing = true;
    final auth = context.read<AuthService>();
    try {
      final success = await auth.setupPin(_pinController.text);
      if (!mounted) return;
      if (success) {
        await auth.importPendingOnboardingPayday();
        await auth.importStartingBalance();
        await _tryStoreBiometricKey();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/');
          });
      } else {
        _isProcessing = false;
        setState(() { _error = true; _errorMsg = 'Could not secure vault'; _loading = false; });
      }
    } catch (_) {
      _isProcessing = false;
      if (mounted) {
        setState(() { _error = true; _errorMsg = 'Vault setup failed'; _loading = false; });
      }
    }
  }
}
