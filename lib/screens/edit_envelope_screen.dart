import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/envelope.dart';
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class EditEnvelopeScreen extends StatefulWidget {
  final Envelope envelope;

  const EditEnvelopeScreen({super.key, required this.envelope});

  @override
  State<EditEnvelopeScreen> createState() => _EditEnvelopeScreenState();
}

class _EditEnvelopeScreenState extends State<EditEnvelopeScreen> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late int _selectedColor;
  late String _selectedIcon;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.envelope.name);
    _amountController = TextEditingController(
      text: widget.envelope.initialAmount.toStringAsFixed(2),
    );
    _selectedColor = widget.envelope.color;
    _selectedIcon = widget.envelope.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);

    final updated = widget.envelope.copyWith(
      name: _nameController.text.trim(),
      initialAmount: amount,
      color: _selectedColor,
      icon: _selectedIcon,
    );

    context.read<EnvelopeProvider>().updateEnvelope(updated).then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = colors.onSurface.withAlpha(10);
    final canCustomColors = context.watch<ThemeProvider>().useCustomEnvelopeColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Edit Envelope'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: colors.onSurface),
              decoration: _inputDecoration('Envelope Name', colors, cardColor),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              style: TextStyle(color: colors.onSurface),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('Amount', colors, cardColor).copyWith(
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: colors.primary, fontSize: 16),
              ),
            ),
            if (canCustomColors) ...[
              const SizedBox(height: 24),
              Text('Color', style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: EnvelopeColors.all.map((c) {
                  final selected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(color: colors.onSurface, width: 2)
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check, color: colors.onSurface, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Icon',
              style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: EnvelopeIcons.all.entries.map((entry) {
                final selected = _selectedIcon == entry.key;
                final iconColor = canCustomColors ? Color(_selectedColor) : colors.primary;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? iconColor.withAlpha(60)
                          : colors.onSurface.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: iconColor, width: 2)
                          : null,
                    ),
                    child: Icon(
                      entry.value,
                      color: selected ? iconColor : colors.onSurface.withAlpha(120),
                      size: 22,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 24, width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
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
