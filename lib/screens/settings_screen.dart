import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../models/recurring_payday.dart';
import '../utils/currency.dart';
import '../widgets/color_picker/color_picker_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDivide = false;
  bool _requireReason = false;
  bool _hardLimit = false;
  ColorScheme get _colors => Theme.of(context).colorScheme;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final provider = context.read<EnvelopeProvider>();
    final autoDivide = await provider.isAutoDivideEnabled();
    final prefs = await SharedPreferences.getInstance();
    final requireReason = prefs.getBool('require_spending_reason') ?? false;
    final hardLimit = prefs.getBool('hard_limit_enabled') ?? false;
    setState(() {
      _autoDivide = autoDivide;
      _requireReason = requireReason;
      _hardLimit = hardLimit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: _colors.surface,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: _colors.onSurface)),
        backgroundColor: _colors.surface,
        foregroundColor: _colors.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Appearance'),
          _settingsCard([
            _SettingTile(
              icon: Icons.brightness_6,
              iconColor: _colors.primary,
              title: 'Theme Mode',
              subtitle: themeProvider.themeModeOption.label,
              onTap: () => _pickThemeMode(themeProvider),
            ),
            _SettingTile(
              icon: Icons.palette_outlined,
              iconColor: themeProvider.accentColor,
              title: 'Accent Color',
              trailing: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: themeProvider.accentColor, shape: BoxShape.circle),
              ),
              onTap: () => _pickAccentColor(themeProvider),
            ),
            _SwitchTile(
              icon: Icons.palette,
              iconColor: _colors.primary,
              title: 'Custom Envelope Colors',
              subtitle: themeProvider.useCustomEnvelopeColors
                  ? 'Each envelope keeps its own color'
                  : 'All envelopes use accent color',
              value: themeProvider.useCustomEnvelopeColors,
              onChanged: (v) => themeProvider.setUseCustomEnvelopeColors(v),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Security'),
          _settingsCard([
            _SettingTile(
              icon: Icons.shield_outlined,
              iconColor: _colors.primary,
              title: 'Security Settings',
              subtitle: 'PIN, password, biometric, encryption',
              onTap: () => Navigator.pushNamed(context, '/security'),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Finance'),
          _settingsCard([
            _SwitchTile(
              icon: Icons.edit_note,
              iconColor: _colors.primary,
              title: 'Require spending reason',
              subtitle: _requireReason ? 'Note is mandatory for every spending' : 'Note is optional when adding spending',
              value: _requireReason,
              onChanged: _toggleRequireReason,
            ),
            _SwitchTile(
              icon: Icons.shield_outlined,
              iconColor: Colors.orangeAccent,
              title: 'Hard spending limit',
              subtitle: _hardLimit ? 'Cannot spend more than remaining balance' : 'Warning only when overspending',
              value: _hardLimit,
              onChanged: _toggleHardLimit,
            ),
            _SwitchTile(
              icon: Icons.auto_graph,
              iconColor: _colors.primary,
              title: 'Auto-allocate paydays',
              subtitle: _autoDivide ? 'Paydays auto-split by saved %' : 'Manual allocation only',
              value: _autoDivide,
              onChanged: _toggleAutoDivide,
            ),
            _SettingTile(
              icon: Icons.percent,
              iconColor: _colors.primary,
              title: 'Set Allocation %',
              onTap: () => Navigator.pushNamed(context, '/alloc-percentages'),
            ),
            const _RecurringPaydayManager(),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Data'),
          _settingsCard([
            _SettingTile(
              icon: Icons.file_download_outlined,
              iconColor: _colors.primary,
              title: 'Export to JSON',
              onTap: () => _export('json'),
            ),
            _SettingTile(
              icon: Icons.table_chart_outlined,
              iconColor: _colors.primary,
              title: 'Export to CSV',
              onTap: () => _export('csv'),
            ),
            _SettingTile(
              icon: Icons.file_upload_outlined,
              iconColor: _colors.primary,
              title: 'Import from JSON',
              onTap: _importData,
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Danger Zone'),
          _settingsCard([
            _SettingTile(
              icon: Icons.delete_forever,
              iconColor: Colors.redAccent,
              title: 'Clear All Data',
              subtitle: 'Removes all envelopes and transactions',
              textColor: Colors.redAccent,
              onTap: _confirmClearData,
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(
        color: _colors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      )),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  void _pickThemeMode(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Theme Mode', style: TextStyle(color: _colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeModeOption.values.map((option) {
            return RadioListTile<ThemeModeOption>(
              title: Text(option.label, style: TextStyle(color: _colors.onSurface)),
              value: option,
              groupValue: themeProvider.themeModeOption,
              activeColor: _colors.primary,
              onChanged: (v) {
                if (v != null) {
                  themeProvider.setThemeMode(v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _pickAccentColor(ThemeProvider themeProvider) async {
    final color = await showColorPicker(context, initialColor: themeProvider.accentColor);
    if (color != null) {
      themeProvider.setAccentColor(color.value);
    }
  }

  Future<void> _toggleAutoDivide(bool v) async {
    final provider = context.read<EnvelopeProvider>();
    await provider.setAutoDivideEnabled(v);
    setState(() => _autoDivide = v);
  }

  Future<void> _toggleRequireReason(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('require_spending_reason', v);
    setState(() => _requireReason = v);
  }

  Future<void> _toggleHardLimit(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hard_limit_enabled', v);
    setState(() => _hardLimit = v);
  }

  Future<void> _export(String format) async {
    final provider = context.read<EnvelopeProvider>();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'coindrop_export_$timestamp.$format';
    final file = File('${dir.path}/$fileName');

    String content;
    if (format == 'json') {
      content = provider.exportToJson();
    } else {
      content = provider.exportToCsv();
    }

    await file.writeAsString(content);
    final fileSize = await file.length();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Exported Successfully', style: TextStyle(color: _colors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined, size: 16, color: _colors.onSurface.withAlpha(100)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(fileName, style: TextStyle(color: _colors.onSurface, fontSize: 14), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text('${(fileSize / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(color: _colors.onSurface.withAlpha(80), fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { Clipboard.setData(ClipboardData(text: file.path)); Navigator.pop(ctx); },
              child: Text('Copy Path', style: TextStyle(color: _colors.onSurface.withAlpha(150))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: _colors.primary),
              child: Text('Done', style: TextStyle(color: _colors.onPrimary)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importData() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Import Data', style: TextStyle(color: _colors.onSurface)),
        content: Text('Paste the backup file path or select a file...\n\nFeature requires file picker.',
            style: TextStyle(color: _colors.onSurface.withAlpha(150))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _colors.onSurface.withAlpha(150)))),
          FilledButton(onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: _colors.primary),
              child: Text('OK', style: TextStyle(color: _colors.onPrimary))),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Data?', style: TextStyle(color: _colors.onSurface)),
        content: Text('This will permanently delete all envelopes, transactions, paydays, and allocations.',
            style: TextStyle(color: _colors.onSurface.withAlpha(150))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _colors.onSurface.withAlpha(150)))),
          TextButton(onPressed: () { Navigator.pop(ctx); _doClearData(); },
              child: Text('Delete All', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Future<void> _doClearData() async {
    final provider = context.read<EnvelopeProvider>();
    await provider.clearAllData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All data cleared'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? textColor;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon, required this.iconColor, required this.title,
    this.subtitle, this.trailing, this.textColor, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(color: textColor ?? colors.onSurface, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12))
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: colors.onSurface.withAlpha(80), size: 20),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: colors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _RecurringPaydayManager extends StatefulWidget {
  const _RecurringPaydayManager();
  @override
  State<_RecurringPaydayManager> createState() => _RecurringPaydayManagerState();
}

class _RecurringPaydayManagerState extends State<_RecurringPaydayManager> {
  List<RecurringPayday> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<EnvelopeProvider>();
    final rules = await provider.getRecurringPaydays();
    if (mounted) setState(() { _rules = rules; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Column(
      children: [
        ..._rules.map((rule) => _RuleTile(rule: rule, onChanged: () => _load())),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextButton.icon(
            onPressed: _showRuleDialog,
            icon: Icon(Icons.add, color: colors.primary),
            label: Text('Add Recurring Payday', style: TextStyle(color: colors.primary)),
          ),
        ),
      ],
    );
  }

  void _showRuleDialog({RecurringPayday? existing}) {
    final colors = Theme.of(context).colorScheme;
    final amountCtl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final noteCtl = TextEditingController(text: existing != null ? existing.note : '');
    String frequency = existing?.frequency ?? 'weekly';
    int? weekday = existing?.weekday ?? DateTime.monday;
    int? monthDay = existing?.monthDay ?? 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(existing != null ? 'Edit Rule' : 'New Recurring Payday',
                  style: TextStyle(color: colors.onSurface)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtl,
                      style: TextStyle(color: colors.onSurface),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                        filled: true,
                        fillColor: colors.onSurface.withAlpha(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: frequency,
                      style: TextStyle(color: colors.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Frequency',
                        labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                        filled: true,
                        fillColor: colors.onSurface.withAlpha(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'fortnightly', child: Text('Fortnightly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (v) => setDialogState(() => frequency = v!),
                    ),
                    const SizedBox(height: 12),
                    if (frequency == 'weekly' || frequency == 'fortnightly')
                      DropdownButtonFormField<int>(
                        value: weekday,
                        style: TextStyle(color: colors.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Day of Week',
                          labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                          filled: true,
                          fillColor: colors.onSurface.withAlpha(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                        onChanged: (v) => setDialogState(() => weekday = v),
                      ),
                    if (frequency == 'monthly')
                      TextField(
                        controller: TextEditingController(text: monthDay.toString()),
                        style: TextStyle(color: colors.onSurface),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Day of Month (1-31)',
                          labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                          filled: true,
                          fillColor: colors.onSurface.withAlpha(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => monthDay = int.tryParse(v) ?? 1,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtl,
                      style: TextStyle(color: colors.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Note',
                        labelStyle: TextStyle(color: colors.onSurface.withAlpha(120)),
                        filled: true,
                        fillColor: colors.onSurface.withAlpha(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: colors.onSurface.withAlpha(150)))),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtl.text);
                    if (amount == null || amount <= 0) return;
                    final rule = RecurringPayday(
                      id: existing?.id,
                      amount: amount,
                      frequency: frequency,
                      weekday: frequency == 'weekly' ? weekday : null,
                      monthDay: frequency == 'monthly' ? monthDay : null,
                      note: noteCtl.text,
                      enabled: existing?.enabled ?? true,
                      lastProcessedDate: existing?.lastProcessedDate,
                    );
                    final provider = context.read<EnvelopeProvider>();
                    if (existing != null) {
                      await provider.updateRecurringPayday(rule);
                    } else {
                      await provider.addRecurringPayday(rule);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  style: FilledButton.styleFrom(backgroundColor: colors.primary),
                  child: Text(existing != null ? 'Save' : 'Add', style: TextStyle(color: colors.onPrimary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RuleTile extends StatelessWidget {
  final RecurringPayday rule;
  final VoidCallback onChanged;

  const _RuleTile({required this.rule, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final freqStr = rule.frequency == 'weekly'
        ? 'Weekly on ${_weekdayName(rule.weekday)}'
        : 'Monthly on day ${rule.monthDay}';
    final amountStr = formatCurrency(rule.amount);

    return ListTile(
      leading: Icon(rule.enabled ? Icons.repeat : Icons.repeat_one,
          color: rule.enabled ? colors.primary : colors.onSurface.withAlpha(100)),
      title: Text(rule.note.isNotEmpty ? rule.note : amountStr,
          style: TextStyle(color: colors.onSurface)),
      subtitle: Text('$freqStr  |  $amountStr',
          style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12)),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: colors.onSurface.withAlpha(120)),
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        onSelected: (v) async {
          final provider = context.read<EnvelopeProvider>();
          if (v == 'toggle') {
            await provider.updateRecurringPayday(rule.copyWith(enabled: !rule.enabled));
            onChanged();
          } else if (v == 'edit') {
            final manager = context.findAncestorStateOfType<_RecurringPaydayManagerState>();
            manager?._showRuleDialog(existing: rule);
          } else if (v == 'delete') {
            await provider.deleteRecurringPayday(rule.id!);
            onChanged();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'toggle', child: Text(rule.enabled ? 'Disable' : 'Enable')),
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  String _weekdayName(int? wd) {
    switch (wd) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
}
