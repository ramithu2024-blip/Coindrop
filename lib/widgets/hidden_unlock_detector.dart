import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/security/build_gate_service.dart';

class HiddenUnlockDetector extends StatefulWidget {
  final Widget child;
  const HiddenUnlockDetector({super.key, required this.child});

  @override
  State<HiddenUnlockDetector> createState() => _HiddenUnlockDetectorState();
}

class _HiddenUnlockDetectorState extends State<HiddenUnlockDetector> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inSeconds > 3) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 7) {
      _tapCount = 0;
      _showUnlockDialog();
    }
  }

  void _showUnlockDialog() {
    final codeCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter access code'),
        content: TextField(
          controller: codeCtl,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Access code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final gate = context.read<BuildGateService>();
              final ok = await gate.attemptUnlock(codeCtl.text.trim());
              if (!ctx.mounted) return;
              if (ok) {
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid code')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: widget.child,
    );
  }
}
