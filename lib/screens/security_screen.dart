import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/pin_input_widget.dart';
import '../services/security/auth_service.dart';
import '../services/security/screenshot_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  int _autoLockMinutes = 5;
  bool _vaultExists = false;
  bool _biometricEnrolled = false;
  bool _biometricAvailable = false;
  bool _screenshotBlocked = true;
  bool _encryptionEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final auth = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final screenshotBlocked = await ScreenshotService.isBlocked();
    setState(() {
      _autoLockMinutes = prefs.getInt('auto_lock_minutes') ?? 5;
      _vaultExists = auth.hasVault;
      _biometricEnrolled = auth.biometricEnrolled;
      _biometricAvailable = auth.biometricAvailable;
      _screenshotBlocked = screenshotBlocked;
      _encryptionEnabled = auth.encryptionEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Vault Status', colors),
          _buildInfoTile(
            colors, Icons.verified_user, 'Database Encryption',
            _encryptionEnabled ? 'AES-256 via SQLCipher' : 'Disabled (plaintext)',
          ),
          _buildInfoTile(colors, Icons.lock, 'Vault PIN', _vaultExists ? 'Configured' : 'Not set'),
          if (_vaultExists) ...[
            const SizedBox(height: 8),
            _buildActionTile(
              colors, _encryptionEnabled ? Icons.lock_open : Icons.lock,
              _encryptionEnabled ? 'Disable Encryption' : 'Enable Encryption',
              _encryptionEnabled ? 'Decrypt database (requires PIN)' : 'Re-encrypt database (requires PIN)',
              () => _toggleEncryption(!_encryptionEnabled),
            ),
            _buildActionTile(colors, Icons.refresh, 'Change PIN', 'Update your vault PIN', _showChangePinDialog),
            _buildActionTile(colors, Icons.dangerous_outlined, 'Destroy Vault', 'Permanently delete all data', _showDestroyVaultDialog),
          ],
          if (_biometricAvailable) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Biometrics', colors),
            _buildBiometricToggle(colors),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('App Behavior', colors),
          _buildScreenshotTile(colors),
          const SizedBox(height: 8),
          _buildAutoLockTile(colors),
          const SizedBox(height: 24),
          _buildSectionHeader('About', colors),
          _buildInfoTile(colors, Icons.info_outline, 'Encryption', 'Your data is encrypted at rest using AES-256 via SQLCipher. The encryption key is derived from your PIN using PBKDF2 with 100,000 iterations.'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(title, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: colors.primary, letterSpacing: 0.5,
      )),
    );
  }

  Widget _buildInfoTile(ColorScheme colors, IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: colors.onSurface.withAlpha(150), size: 22),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(80))),
      ),
    );
  }

  Widget _buildActionTile(ColorScheme colors, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: colors.onSurface.withAlpha(150), size: 22),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(80))),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBiometricToggle(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: Icon(Icons.fingerprint, color: colors.primary, size: 22),
        title: Text('Fingerprint Unlock', style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface)),
        subtitle: Text(
          _biometricEnrolled ? 'Fingerprint can unlock vault' : 'Requires PIN verify to enable',
          style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(80)),
        ),
        value: _biometricEnrolled,
        activeColor: colors.primary,
        onChanged: (v) => _toggleBiometric(v),
      ),
    );
  }

  Future<void> _toggleBiometric(bool enable) async {
    final auth = context.read<AuthService>();
    final colors = Theme.of(context).colorScheme;
    if (enable) {
      final pinCtrl = TextEditingController();
      final pinFocus = FocusNode();
      bool processing = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Enable Fingerprint Unlock', style: TextStyle(color: colors.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your PIN to enable fingerprint unlock.',
                    style: TextStyle(color: colors.onSurface.withAlpha(150), fontSize: 14)),
                const SizedBox(height: 16),
                PinInputWidget(
                  controller: pinCtrl,
                  focusNode: pinFocus,
                  length: pinCtrl.text.length,
                  colors: colors,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
              FilledButton(
                onPressed: processing
                    ? null
                    : () async {
                        if (pinCtrl.text.length != 4) return;
                        setDialogState(() => processing = true);
                        try {
                          final ok = await auth.verifyPin(pinCtrl.text);
                          if (ok) {
                            await auth.storeBiometricKey();
                            await auth.setBiometricUserEnabled(true);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            setDialogState(() => processing = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: const Text('Incorrect PIN'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => processing = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                child: Text(processing ? 'Verifying...' : 'Enable'),
              ),
            ],
          ),
        ),
      );
      pinCtrl.dispose();
      pinFocus.dispose();
      if (confirmed == true && mounted) {
        setState(() => _biometricEnrolled = true);
      }
    } else {
      await auth.deleteBiometricKey();
      await auth.setBiometricUserEnabled(false);
      if (mounted) setState(() => _biometricEnrolled = false);
    }
  }

  Widget _buildScreenshotTile(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: Icon(Icons.screenshot_monitor_outlined, color: colors.onSurface.withAlpha(150), size: 22),
        title: Text('Block Screenshots', style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface)),
        subtitle: Text(
          _screenshotBlocked ? 'Screen recording & app switcher preview blocked' : 'Screenshots allowed',
          style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(80)),
        ),
        value: _screenshotBlocked,
        activeColor: colors.primary,
        onChanged: (v) async {
          await ScreenshotService.setBlocked(v);
          setState(() => _screenshotBlocked = v);
        },
      ),
    );
  }

  Widget _buildAutoLockTile(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(Icons.timer_outlined, color: colors.onSurface.withAlpha(150), size: 22),
        title: Text('Auto-lock Timer', style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface)),
        subtitle: Text('$_autoLockMinutes min', style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(80))),
        trailing: SizedBox(
          width: 120,
          child: Slider(
            value: _autoLockMinutes.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$_autoLockMinutes min',
            activeColor: colors.primary,
            onChanged: (v) async {
              final minutes = v.round();
              setState(() => _autoLockMinutes = minutes);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('auto_lock_minutes', minutes);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePinDialog() async {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final colors = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change PIN', style: TextStyle(color: colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinCtrl, obscureText: true, maxLength: 4,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Current PIN', counterText: '',
                hintStyle: TextStyle(color: colors.onSurface.withAlpha(80)),
                filled: true, fillColor: colors.onSurface.withAlpha(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinCtrl, obscureText: true, maxLength: 4,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'New PIN', counterText: '',
                hintStyle: TextStyle(color: colors.onSurface.withAlpha(80)),
                filled: true, fillColor: colors.onSurface.withAlpha(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl, obscureText: true, maxLength: 4,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Confirm new PIN', counterText: '',
                hintStyle: TextStyle(color: colors.onSurface.withAlpha(80)),
                filled: true, fillColor: colors.onSurface.withAlpha(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (newPinCtrl.text.length != 4) return;
              if (newPinCtrl.text != confirmCtrl.text) return;
              try {
                await context.read<AuthService>().changePin(oldPinCtrl.text, newPinCtrl.text);
                Navigator.pop(ctx, true);
              } catch (_) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed: $_'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: Text('Change PIN'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('PIN changed successfully'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showDestroyVaultDialog() async {
    final confirmCtrl = TextEditingController();
    final colors = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Destroy Vault', style: TextStyle(color: colors.error)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: colors.error),
            const SizedBox(height: 16),
            Text('This will permanently delete ALL your financial data, envelopes, transactions, and settings. This action cannot be undone.',
              style: TextStyle(color: colors.onSurface, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: confirmCtrl, maxLength: 4,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Enter your PIN to confirm',
                counterText: '',
                hintStyle: TextStyle(color: colors.onSurface.withAlpha(80)),
                filled: true, fillColor: colors.onSurface.withAlpha(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              if (confirmCtrl.text.length != 4) return;
              final auth = context.read<AuthService>();
              if (await auth.resetWithPin(confirmCtrl.text)) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text('Destroy Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Vault destroyed. App reset.'), behavior: SnackBarBehavior.floating),
      );
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _toggleEncryption(bool enable) async {
    final auth = context.read<AuthService>();
    final colors = Theme.of(context).colorScheme;
    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    bool processing = false;

    // Step 1: Verify PIN
    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(enable ? 'Enable Encryption' : 'Disable Encryption',
              style: TextStyle(color: colors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                enable
                    ? 'Enter your PIN to re-encrypt the database with AES-256 via SQLCipher.'
                    : 'Enter your PIN to decrypt the database to plaintext.',
                style: TextStyle(color: colors.onSurface.withAlpha(150), fontSize: 14),
              ),
              const SizedBox(height: 16),
              PinInputWidget(
                controller: pinCtrl,
                focusNode: pinFocus,
                length: pinCtrl.text.length,
                colors: colors,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
            FilledButton(
              onPressed: processing ? null : () async {
                if (pinCtrl.text.length != 4) return;
                setDialogState(() => processing = true);
                try {
                  final ok = await auth.verifyPin(pinCtrl.text);
                  if (ok) {
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } else {
                    setDialogState(() => processing = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: const Text('Incorrect PIN'), behavior: SnackBarBehavior.floating),
                    );
                  }
                } catch (e) {
                  setDialogState(() => processing = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: Text(processing ? 'Verifying...' : 'Continue'),
            ),
          ],
        ),
      ),
    );

    if (verified != true) {
      pinCtrl.dispose();
      pinFocus.dispose();
      return;
    }

    // Step 2: Progress dialog with ValueNotifier
    final progressMsg = ValueNotifier('');

    void updateProgress(String msg) {
      progressMsg.value = msg;
    }

    // Close the PIN verify dialog first (already popped by Navigator.pop above).
    // Now show the progress dialog.
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: ValueListenableBuilder<String>(
          valueListenable: progressMsg,
          builder: (_, msg, __) => Row(
            children: [
              const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 16),
              Flexible(
                child: Text(msg, style: TextStyle(color: colors.onSurface)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final db = auth.dbHelper;

      // Step 3: Do the work
      updateProgress('Exporting data from database...');
      final data = await db.exportAllData();

      if (enable) {
        updateProgress('Encrypting database...');
        final keyHex = await auth.deriveKeyHexFromPin(pinCtrl.text);
        await db.deleteDatabaseFile();
        await db.open(keyHex);
        auth.setEncryptionEnabled(true);
      } else {
        updateProgress('Decrypting database...');
        await db.deleteDatabaseFile();
        await db.openPlain();
        auth.setEncryptionEnabled(false);
      }

      updateProgress('Importing data into database...');
      await db.importAllData(data);

      updateProgress('Done!');

      // ignore: use_build_context_synchronously
      if (mounted) Navigator.pop(context); // close progress dialog

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable
              ? 'Encryption enabled. Database is now protected with AES-256.'
              : 'Encryption disabled. Database is now plaintext.'),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // ignore: use_build_context_synchronously
      setState(() {});
    } catch (e) {
      // ignore: use_build_context_synchronously
      if (mounted) Navigator.pop(context); // close progress dialog

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${enable ? 'enable' : 'disable'} encryption: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      pinCtrl.dispose();
      pinFocus.dispose();
    }
  }
}
