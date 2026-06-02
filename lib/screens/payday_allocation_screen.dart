import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/payday.dart';
import '../models/allocation.dart';
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../utils/constants.dart';

class PaydayAllocationScreen extends StatefulWidget {
  const PaydayAllocationScreen({super.key});

  @override
  State<PaydayAllocationScreen> createState() => _PaydayAllocationScreenState();
}

class _PaydayAllocationScreenState extends State<PaydayAllocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;
  double _paycheckAmount = 0;
  bool _autoDivide = false;
  final Map<int, double> _allocations = {};
  bool _amountSet = false;
  Map<int, double> _savedPercentages = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _allocatedTotal =>
      _allocations.values.fold(0.0, (s, v) => s + v);

  double get _remaining => _paycheckAmount - _allocatedTotal;

  bool get _isOverAllocated => _remaining < -0.01;

  Future<void> _loadSettings() async {
    final provider = context.read<EnvelopeProvider>();
    _savedPercentages = await provider.loadAllocationPercentages();
    _autoDivide = await provider.isAutoDivideEnabled();
    if (mounted) setState(() {});
  }

  void _setAmount(double amount) {
    setState(() {
      _paycheckAmount = amount;
      _amountSet = true;
    });
  }

  void _applyAutoDivide() {
    if (_savedPercentages.isEmpty) {
      if (provider.envelopes.isEmpty) return;
      final equalShare = _paycheckAmount / provider.envelopes.length;
      for (final env in provider.envelopes) {
        if (env.id != null) _allocations[env.id!] = equalShare;
      }
    } else {
      for (final env in provider.envelopes) {
        if (env.id != null && _savedPercentages.containsKey(env.id)) {
          final pct = _savedPercentages[env.id]! / 100;
          _allocations[env.id!] = (_paycheckAmount * pct);
        }
      }
    }
    setState(() {});
  }

  EnvelopeProvider get provider => context.read<EnvelopeProvider>();

  void _addAllocation(int envelopeId, double amount) {
    setState(() {
      if (amount <= 0) {
        _allocations.remove(envelopeId);
      } else {
        _allocations[envelopeId] = amount;
      }
    });
  }

  void _save() {
    setState(() => _isSaving = true);

    final now = DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now());
    final payday = Payday(
      amount: _paycheckAmount,
      note: _noteController.text.trim().isEmpty
          ? 'Payday'
          : _noteController.text.trim(),
      date: now,
    );

    final allocations = _allocations.entries
        .where((e) => e.value > 0)
        .map((e) => Allocation(
              paydayId: 0,
              envelopeId: e.key,
              amount: e.value,
            ))
        .toList();

    final p = provider;
    p.addPayday(payday, allocations).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_allocations.isNotEmpty
                ? 'Payday recorded and allocated!'
                : 'Payday recorded! \$ ${formatCurrency(_paycheckAmount)} added to balance'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = colors.onSurface.withAlpha(10);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('New Payday'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_amountSet) ...[
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: colors.onSurface, fontSize: 24),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Paycheck Amount',
                  labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: colors.primary, fontSize: 22),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final amt = double.tryParse(v.trim());
                  if (amt == null || amt <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                style: TextStyle(color: colors.onSurface),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                  hintText: 'e.g. Monthly salary',
                  hintStyle: TextStyle(color: colors.onSurface.withAlpha(60)),
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
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _setAmount(double.parse(_amountController.text.trim()));
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onPrimary)),
                ),
              ),
            ] else ...[
              _buildSummaryCard(colors),
              const SizedBox(height: 20),
              _buildAllocationSection(colors),
              const SizedBox(height: 24),
              _buildActionButtons(colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary.withAlpha(35), colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('Paycheck', formatCurrency(_paycheckAmount), colors.onSurface, colors),
              _summaryItem('Allocated', formatCurrency(_allocatedTotal), colors.primary, colors),
              _summaryItem('To Balance', formatCurrency(_remaining),
                  _isOverAllocated ? Colors.redAccent : colors.primary, colors),
            ],
          ),
          if (_allocatedTotal > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_allocatedTotal / _paycheckAmount).clamp(0.0, 1.0),
                backgroundColor: colors.onSurface.withAlpha(20),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isOverAllocated ? Colors.redAccent : colors.primary,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_allocatedTotal / _paycheckAmount * 100).toStringAsFixed(0)}% allocated',
              style: TextStyle(color: colors.onSurface.withAlpha(100), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color, ColorScheme colors) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAllocationSection(ColorScheme colors) {
    return Consumer<EnvelopeProvider>(
      builder: (context, provider, _) {
        if (provider.envelopes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.onSurface.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('No envelopes yet', style: TextStyle(color: colors.onSurface.withAlpha(120))),
                const SizedBox(height: 4),
                Text('Payday will be added to your balance', style: TextStyle(color: colors.onSurface.withAlpha(80), fontSize: 13)),
              ],
            ),
          );
        }

        final useCustomColors = context.watch<ThemeProvider>().useCustomEnvelopeColors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Allocate to Envelopes', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface,
                )),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Auto Divide', style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(120))),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 28,
                      child: Switch.adaptive(
                        value: _autoDivide,
                        activeColor: colors.primary,
                        onChanged: (v) {
                          setState(() => _autoDivide = v);
                          if (v) _applyAutoDivide();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...provider.envelopes.map((env) {
              final allocated = _allocations[env.id] ?? 0.0;
              final envelopeColor = useCustomColors ? Color(env.color) : colors.primary;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                  border: allocated > 0
                      ? Border.all(color: envelopeColor.withAlpha(80))
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(EnvelopeIcons.getIcon(env.icon),
                            color: envelopeColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(env.name,
                              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500)),
                        ),
                        if (allocated > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(formatCurrency(allocated),
                                style: TextStyle(color: envelopeColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: TextEditingController(
                              text: allocated > 0 ? allocated.toStringAsFixed(0) : '',
                            ),
                            style: TextStyle(color: colors.onSurface, fontSize: 14),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              hintText: '\$0',
                              hintStyle: TextStyle(color: colors.onSurface.withAlpha(60)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: colors.onSurface.withAlpha(20),
                            ),
                            onChanged: (v) {
                              final amt = double.tryParse(v);
                              if (amt != null && amt >= 0) {
                                _addAllocation(env.id!, amt);
                              } else if (v.isEmpty) {
                                _addAllocation(env.id!, 0);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (allocated > 0 && _paycheckAmount > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (allocated / _paycheckAmount).clamp(0.0, 1.0),
                          backgroundColor: colors.onSurface.withAlpha(20),
                          valueColor: AlwaysStoppedAnimation<Color>(envelopeColor),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Consumer<EnvelopeProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            if (provider.envelopes.isNotEmpty && !_autoDivide)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_savedPercentages.isNotEmpty) {
                      for (final env in provider.envelopes) {
                        if (env.id != null && _savedPercentages.containsKey(env.id)) {
                          final pct = _savedPercentages[env.id]! / 100;
                          _allocations[env.id!] = (_paycheckAmount * pct);
                        }
                      }
                    } else {
                      final equalShare = _paycheckAmount / provider.envelopes.length;
                      for (final env in provider.envelopes) {
                        if (env.id != null) _allocations[env.id!] = equalShare;
                      }
                    }
                    setState(() {});
                  },
                  icon: const Icon(Icons.equalizer, size: 18),
                  label: const Text('Use Saved % / Split Equally'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withAlpha(80)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            if (provider.envelopes.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _allocations.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All Allocations'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface.withAlpha(120),
                    side: BorderSide(color: colors.onSurface.withAlpha(40)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 24, width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Complete Payday',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onPrimary)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _amountSet = false),
              child: Text('Change Amount', style: TextStyle(color: colors.onSurface.withAlpha(120))),
            ),
          ],
        );
      },
    );
  }
}
