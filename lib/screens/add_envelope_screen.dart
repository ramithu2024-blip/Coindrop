import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/envelope.dart';
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class AddEnvelopeScreen extends StatefulWidget {
  const AddEnvelopeScreen({super.key});

  @override
  State<AddEnvelopeScreen> createState() => _AddEnvelopeScreenState();
}

class _AddEnvelopeScreenState extends State<AddEnvelopeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  int _selectedColor = EnvelopeColors.defaultColor;
  String _selectedIcon = 'savings';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = colors.onSurface.withAlpha(10);
    final canCustomColors = context.watch<ThemeProvider>().useCustomEnvelopeColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('New Envelope'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Envelope Name',
                labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                hintText: 'e.g. Groceries, Rent, Fun',
                hintStyle: TextStyle(color: colors.onSurface.withAlpha(60)),
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
                if (v == null || v.trim().isEmpty) return 'Enter a name';
                return null;
              },
            ),
            if (canCustomColors) ...[
              const SizedBox(height: 24),
              Text('Color', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: EnvelopeColors.all.asMap().entries.map((entry) {
                  final color = entry.value;
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: colors.onSurface, width: 2.5) : null,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Color(color).computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            Text('Icon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: EnvelopeIcons.all.entries.map((entry) {
                final iconName = entry.key;
                final iconData = entry.value;
                final isSelected = _selectedIcon == iconName;
                final iconColor = canCustomColors ? Color(_selectedColor) : colors.primary;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = iconName),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? iconColor.withAlpha(30) : colors.onSurface.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: iconColor, width: 2) : null,
                    ),
                    child: Icon(iconData,
                        color: isSelected ? iconColor : colors.onSurface.withAlpha(120), size: 22),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
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
                    : Text('Create Envelope',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final envelope = Envelope(
      name: _nameController.text.trim(),
      initialAmount: 0,
      createdAt: DateTime.now().toIso8601String(),
      color: _selectedColor,
      icon: _selectedIcon,
    );
    await context.read<EnvelopeProvider>().addEnvelope(envelope);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${envelope.name} created'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }
}
