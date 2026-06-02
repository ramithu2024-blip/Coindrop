import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/envelope.dart';
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class AllocPercentagesScreen extends StatefulWidget {
  const AllocPercentagesScreen({super.key});

  @override
  State<AllocPercentagesScreen> createState() =>
      _AllocPercentagesScreenState();
}

class _AllocPercentagesScreenState extends State<AllocPercentagesScreen> {
  final Map<int, double> _percentages = {};
  bool _loaded = false;

  @override
  void dispose() {
    super.dispose();
  }

  double get _total => _percentages.values.fold(0.0, (s, v) => s + v);
  double get _remaining => 100 - _total;
  bool get _isValid => (_total - 100).abs() < 0.5;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Auto-Allocate %'),
        elevation: 0,
      ),
      body: Consumer<EnvelopeProvider>(
        builder: (context, provider, _) {
          if (!_loaded) {
            _loadPercentages(provider);
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.envelopes.isEmpty) {
            return Center(
              child: Text(
                'Create envelopes first',
                style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 16),
              ),
            );
          }

          final useCustomColors = context.watch<ThemeProvider>().useCustomEnvelopeColors;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildInfoCard(colors),
              const SizedBox(height: 16),
              ...provider.envelopes.map((env) => _buildSliderTile(env, colors, useCustomColors)),
              const SizedBox(height: 16),
              _buildTotalRow(colors),
              const SizedBox(height: 24),
              _buildSaveButton(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Set default allocation percentages',
            style: TextStyle(
                color: colors.onSurface.withAlpha(150), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Used when auto-allocate is enabled',
            style: TextStyle(color: colors.onSurface.withAlpha(100), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(Envelope env, ColorScheme colors, bool useCustomColors) {
    final pct = _percentages[env.id] ?? 0.0;
    final envelopeColor = useCustomColors ? Color(env.color) : colors.primary;
    final pctInt = pct.round();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(EnvelopeIcons.getIcon(env.icon),
                  color: envelopeColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(env.name,
                    style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pct > 0
                      ? envelopeColor.withAlpha(40)
                      : colors.onSurface.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pctInt%',
                  style: TextStyle(
                    color: pct > 0 ? envelopeColor : colors.onSurface.withAlpha(120),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: envelopeColor,
              thumbColor: envelopeColor,
              inactiveTrackColor: colors.onSurface.withAlpha(30),
              overlayColor: envelopeColor.withAlpha(30),
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: pct,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) => _update(env.id!, v),
            ),
          ),
        ],
      ),
    );
  }

  void _update(int envId, double value) {
    setState(() {
      _percentages[envId] = value;
    });
  }

  Widget _buildTotalRow(ColorScheme colors) {
    final isValid = _isValid;
    final remaining = _remaining;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValid
              ? colors.primary.withAlpha(80)
              : remaining < 0
                  ? Colors.redAccent.withAlpha(80)
                  : Colors.orange.withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Allocated',
                style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                '${_total.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: isValid
                      ? colors.primary
                      : remaining < 0
                          ? Colors.redAccent
                          : Colors.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!isValid) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_total / 100).clamp(0.0, 1.0),
                backgroundColor: colors.onSurface.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  remaining < 0 ? Colors.redAccent : Colors.orange,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              remaining < 0
                  ? 'Over by ${(-remaining).toStringAsFixed(0)}% — reduce some'
                  : '${remaining.toStringAsFixed(0)}% remaining — increase to 100%',
              style: TextStyle(
                color: remaining < 0 ? Colors.redAccent : Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton(EnvelopeProvider provider) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isValid ? () => _save(provider) : null,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Save Percentages',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _loadPercentages(EnvelopeProvider provider) async {
    final saved = await provider.loadAllocationPercentages();
    _percentages.addAll(saved);
    for (final env in provider.envelopes) {
      if (env.id != null && !_percentages.containsKey(env.id)) {
        _percentages[env.id!] = 0.0;
      }
    }
    setState(() => _loaded = true);
  }

  void _save(EnvelopeProvider provider) async {
    await provider.saveAllocationPercentages(_percentages);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Percentages saved'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }
}
