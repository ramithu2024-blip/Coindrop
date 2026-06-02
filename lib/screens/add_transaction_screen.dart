import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/envelope.dart';
import '../models/transaction.dart' as model;
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../utils/constants.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Envelope? _selectedEnvelope;
  bool _isSaving = false;
  bool _requireReason = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Envelope && _selectedEnvelope == null) {
      _selectedEnvelope = arg;
    }
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _requireReason = prefs.getBool('require_spending_reason') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEnvelope == null) {
      _showSnack('Please select an envelope');
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final provider = context.read<EnvelopeProvider>();
    final totalFunding = provider.getTotalFunding(_selectedEnvelope!.id!);
    final remaining = provider.calculateRemaining(_selectedEnvelope!.id!);
    final prefs = await SharedPreferences.getInstance();
    final hardLimit = prefs.getBool('hard_limit_enabled') ?? false;

    if (amount > remaining) {
      _showSnack(
        'Insufficient balance! Available: ${formatCurrency(remaining)}',
      );
      return;
    }

    // Spending Guard: warn if envelope is running low
    if (totalFunding > 0 && remaining > 0 && remaining < totalFunding * 0.2) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                Text('Low Budget', style: TextStyle(color: c.onSurface)),
              ],
            ),
            content: Text(
              '${_selectedEnvelope!.name} only has ${formatCurrency(remaining)} remaining (${(remaining / totalFunding * 100).toStringAsFixed(0)}% of funding).\n\n${hardLimit ? 'Hard limit is ON — this transaction is blocked to protect your budget.' : 'You can still proceed if needed.'}',
              style: TextStyle(color: c.onSurface.withAlpha(180), fontSize: 14),
            ),
            actions: hardLimit
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Go Back'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Spend Anyway'),
                    ),
                  ],
          );
        },
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);

    final transaction = model.Transaction(
      envelopeId: _selectedEnvelope!.id!,
      amount: amount,
      note: _noteController.text.trim().isEmpty
          ? 'Spending'
          : _noteController.text.trim(),
      date: DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now()),
    );

    try {
      await provider.addTransaction(transaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction added'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Failed to save transaction: $e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = colors.onSurface.withAlpha(10);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Add Spending'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer<EnvelopeProvider>(
                builder: (context, provider, _) {
                  final envUseCustom = context.watch<ThemeProvider>().useCustomEnvelopeColors;
                  return DropdownButtonFormField<Envelope>(
                    value: _selectedEnvelope,
                    dropdownColor: Theme.of(context).cardTheme.color,
                    style: TextStyle(color: colors.onSurface),
                    decoration: _inputDecoration('Envelope', colors, cardColor),
                    hint: Text('Select an envelope', style: TextStyle(color: colors.onSurface.withAlpha(100))),
                    items: provider.envelopes.map((e) {
                      final remaining = provider.calculateRemaining(e.id!);
                      final envelopeColor = envUseCustom ? Color(e.color) : colors.primary;
                      return DropdownMenuItem(
                        value: e,
                        child: Row(
                          children: [
                            Icon(EnvelopeIcons.getIcon(e.icon), color: envelopeColor, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              '${e.name} (${formatCurrency(remaining)})',
                              style: TextStyle(color: colors.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedEnvelope = v),
                    validator: (v) => v == null ? 'Select an envelope' : null,
                  );
                },
              ),
              const SizedBox(height: 20),
              if (_selectedEnvelope != null)
                Consumer<EnvelopeProvider>(
                  builder: (context, provider, _) {
                    final remaining = provider.calculateRemaining(_selectedEnvelope!.id!);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: remaining < 0
                            ? Colors.redAccent.withAlpha(20)
                            : cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: remaining < 0 ? Colors.redAccent : colors.primary, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Available: ${formatCurrency(remaining)}',
                              style: TextStyle(
                                color: remaining < 0 ? Colors.redAccent : colors.onSurface.withAlpha(180),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (_selectedEnvelope != null) const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: colors.onSurface),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Amount', colors, cardColor).copyWith(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: colors.primary, fontSize: 16),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final amt = double.tryParse(v.trim());
                  if (amt == null || amt <= 0) return 'Enter a valid positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _noteController,
                style: TextStyle(color: colors.onSurface),
                decoration: _inputDecoration(
                  _requireReason ? 'Note (required)' : 'Note (optional)',
                  colors, cardColor,
                ).copyWith(
                  hintText: _requireReason ? 'e.g. Weekly groceries (required)' : 'e.g. Weekly groceries',
                  hintStyle: TextStyle(color: colors.onSurface.withAlpha(80)),
                ),
                validator: _requireReason
                    ? (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter a reason for this spending';
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: colors.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurface),
                        )
                      : const Text(
                          'Add Spending',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, ColorScheme colors, Color cardColor) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.onSurface.withAlpha(150)),
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary),
      ),
    );
  }
}
