import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/envelope_provider.dart';
import '../services/security/auth_service.dart';

class ExpiredScreen extends StatefulWidget {
  final String title;
  final String message;
  final bool showUnlockField;
  final Future<bool> Function(String code)? onUnlock;

  const ExpiredScreen({
    super.key,
    this.title = 'This build has expired',
    this.message = 'Export your data to continue using CoinDrop',
    this.showUnlockField = false,
    this.onUnlock,
  });

  @override
  State<ExpiredScreen> createState() => _ExpiredScreenState();
}

class _ExpiredScreenState extends State<ExpiredScreen> {
  final _codeCtl = TextEditingController();
  bool _codeError = false;
  bool _unlocking = false;

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    final auth = context.read<AuthService>();
    try {
      final provider = EnvelopeProvider(auth);
      await provider.loadEnvelopes();
      final json = provider.exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/coindrop_export.json');
      await file.writeAsString(json);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _submitCode() async {
    if (_unlocking || widget.onUnlock == null) return;
    setState(() { _codeError = false; _unlocking = true; });
    final ok = await widget.onUnlock!(_codeCtl.text.trim());
    if (!mounted) return;
    if (!ok) {
      setState(() { _codeError = true; _unlocking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty, size: 72, color: colors.error),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                widget.message,
                style: TextStyle(fontSize: 15, color: colors.onSurface.withAlpha(180)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.download),
                label: const Text('Export Data'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.system_update_outlined),
                label: const Text('Check for updates'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(220, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (widget.showUnlockField) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Already have a license code?',
                  style: TextStyle(fontSize: 14, color: colors.onSurface.withAlpha(150)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeCtl,
                  obscureText: true,
                  maxLength: 32,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurface, fontSize: 16, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: 'Enter unlock code',
                    counterText: '',
                    hintStyle: TextStyle(color: colors.onSurface.withAlpha(80)),
                    filled: true,
                    fillColor: colors.onSurface.withAlpha(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _codeError ? 'Invalid code' : null,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _unlocking ? null : _submitCode,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_unlocking ? 'Verifying...' : 'Unlock Lifetime Access'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
