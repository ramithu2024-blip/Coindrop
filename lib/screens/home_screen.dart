import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../providers/envelope_provider.dart';
import '../services/security/auth_service.dart';
import '../models/payday.dart';
import '../models/recurring_payday.dart';
import '../widgets/balance_header.dart';
import '../widgets/envelope_card.dart';
import '../widgets/transaction_tile.dart';
import '../screens/insights_screen.dart';
import '../screens/payday_history_screen.dart';
import '../utils/currency.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentTab = 0;
  bool _initialized = false;
  RecurringPayday? _nextPayday;
  bool _paydayDismissed = false;
  bool _paydaySkipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authService = context.read<AuthService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      authService.lock();
      context.read<EnvelopeProvider>().clearCache();
    }
  }

  Future<void> _initData() async {
    setState(() => _initialized = true);
    try {
      final provider = context.read<EnvelopeProvider>();
      await provider.loadEnvelopes();
      await provider.processRecurringPaydays();

      final rules = await provider.getRecurringPaydays();
      _nextPayday = rules.isNotEmpty ? rules.first : null;

      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool _isPaydayToday() {
    if (_nextPayday == null || _paydayDismissed) return false;
    if (_nextPayday!.lastProcessedDate != null) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_nextPayday!.lastProcessedDate == todayStr) return false;
    }
    final now = DateTime.now();
    if (_nextPayday!.frequency == 'weekly') {
      return _nextPayday!.weekday == now.weekday;
    } else if (_nextPayday!.frequency == 'fortnightly') {
      return _nextPayday!.weekday == now.weekday;
    } else if (_nextPayday!.frequency == 'monthly') {
      return _nextPayday!.monthDay == now.day;
    }
    return false;
  }

  bool _showMissedReminder() {
    if (_nextPayday == null || _paydaySkipped) return false;
    if (_isPaydayToday()) return false;
    if (_nextPayday!.lastProcessedDate != null) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_nextPayday!.lastProcessedDate == todayStr) return false;
    }
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (_nextPayday!.frequency == 'weekly') {
      return _nextPayday!.weekday == yesterday.weekday;
    } else if (_nextPayday!.frequency == 'fortnightly') {
      return _nextPayday!.weekday == yesterday.weekday;
    } else if (_nextPayday!.frequency == 'monthly') {
      return _nextPayday!.monthDay == yesterday.day;
    }
    return false;
  }

  Future<void> _confirmPaydayReceived() async {
    final provider = context.read<EnvelopeProvider>();
    final amount = _nextPayday?.amount ?? 0;
    if (amount <= 0) return;

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    await provider.addPayday(
      Payday(
        amount: amount,
        note: _nextPayday?.note ?? 'Salary',
        date: '${dateStr}T09:00:00',
      ),
      [],
    );

    if (_nextPayday != null && mounted) {
      final updated = _nextPayday!.copyWith(lastProcessedDate: dateStr);
      await provider.updateRecurringPayday(updated);
      setState(() {
        _nextPayday = updated;
        _paydayDismissed = true;
        _paydaySkipped = false;
      });
    } else {
      setState(() {
        _paydayDismissed = true;
        _paydaySkipped = false;
      });
    }

    if (!mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.dashboardPaycheckConfirmed} — ${formatCurrency(amount)}'),
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _skipPayday() {
    setState(() => _paydaySkipped = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppStrings.dashboardPaycheckLater),
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final widget = Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'CoinDrop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: colors.onSurface.withAlpha(150)),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: _initialized
          ? IndexedStack(
              index: _currentTab,
              children:  [
                _DashboardTab(
                  onPaydayReceived: _confirmPaydayReceived,
                  onPaydaySkipped: _skipPayday,
                  isPaydayToday: _isPaydayToday(),
                  showMissedReminder: _showMissedReminder(),
                  nextPayday: _nextPayday,
                ),
                const InsightsScreen(),
                const PaydayHistoryScreen(),
              ],
            )
          : Center(child: CircularProgressIndicator(color: colors.primary)),
      bottomNavigationBar: _buildBottomNav(colors),
      floatingActionButton: _currentTab == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'payday',
                  onPressed: () => Navigator.pushNamed(context, '/payday-allocate'),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: const Icon(Icons.payments),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'envelope',
                  onPressed: () => Navigator.pushNamed(context, '/add-envelope'),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  icon: const Icon(Icons.add),
                  label: const Text('Envelope'),
                ),
              ],
            )
          : null,
    );

    return widget;
  }

  Widget _buildBottomNav(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.onSurface.withAlpha(25)),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurface.withAlpha(100),
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Paydays'),
        ],
      ),
    );
  }

  void _showSettingsMenu() {
    final colors = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? colors.surface;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _menuItem(ctx, Icons.file_download_outlined, 'Export to JSON',
                  colors, () { Navigator.pop(ctx); _exportData('json'); }),
              _menuItem(ctx, Icons.table_chart_outlined, 'Export to CSV',
                  colors, () { Navigator.pop(ctx); _exportData('csv'); }),
              _menuItem(ctx, Icons.percent, 'Set Allocation %',
                  colors, () { Navigator.pop(ctx); _showAllocationPercentages(); }),
              _menuItem(ctx, Icons.settings_outlined, 'Settings',
                  colors, () { Navigator.pop(ctx); Navigator.pushNamed(context, '/settings'); }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext ctx, IconData icon, String title,
      ColorScheme colors, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: colors.onSurface.withAlpha(150)),
      title: Text(title, style: TextStyle(color: colors.onSurface)),
      onTap: onTap,
    );
  }

  Future<void> _exportData(String format) async {
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $fileName'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAllocationPercentages() {
    Navigator.pushNamed(context, '/alloc-percentages');
  }
}

class _DashboardTab extends StatelessWidget {
  final Future<void> Function()? onPaydayReceived;
  final VoidCallback? onPaydaySkipped;
  final bool isPaydayToday;
  final bool showMissedReminder;
  final RecurringPayday? nextPayday;

  const _DashboardTab({
    this.onPaydayReceived,
    this.onPaydaySkipped,
    this.isPaydayToday = false,
    this.showMissedReminder = false,
    this.nextPayday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Consumer<EnvelopeProvider>(
      builder: (context, provider, _) {
        final trendPct = provider.getSpendingTrendPercent();
        final daysUntilPayday = provider.getDaysUntilPayday(nextPayday);

        return RefreshIndicator(
          onRefresh: () => provider.loadEnvelopes(),
          color: colors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const BalanceHeader(),
              _MoneyRealityCheck(
                provider: provider,
                trendPercent: trendPct,
                daysUntilPayday: daysUntilPayday,
              ),
              if (isPaydayToday && nextPayday != null)
                _PaydayReminderCard(
                  amount: nextPayday!.amount,
                  note: nextPayday!.note,
                  onReceived: onPaydayReceived,
                  onSkipped: onPaydaySkipped,
                ),
              if (showMissedReminder && nextPayday != null)
                _MissedPaydayCard(
                  amount: nextPayday!.amount,
                  note: nextPayday!.note,
                  onReceived: onPaydayReceived,
                ),
              if (provider.envelopes.isEmpty)
                _buildEmptyState(context, colors)
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Envelopes',
                    style: AppTextStyles.sectionTitle(context),
                  ),
                ),
                ...provider.envelopes.map(
                  (e) => EnvelopeCard(envelope: e),
                ),
              ],
              if (provider.recentTransactions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Recent Transactions',
                    style: AppTextStyles.sectionTitle(context),
                  ),
                ),
                ...provider.recentTransactions.map(
                  (t) => TransactionTile(transaction: t),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: colors.onSurface.withAlpha(50)),
          const SizedBox(height: 16),
          Text(
            AppStrings.dashboardEmptyTitle,
            style: AppTextStyles.emptyTitle(context),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.dashboardEmptyBody,
            style: AppTextStyles.emptyBody(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PaydayReminderCard extends StatelessWidget {
  final double amount;
  final String note;
  final VoidCallback? onReceived;
  final VoidCallback? onSkipped;

  const _PaydayReminderCard({
    super.key,
    required this.amount,
    required this.note,
    this.onReceived,
    this.onSkipped,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary.withAlpha(25), colors.primary.withAlpha(8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.primary.withAlpha(35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.payments, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.paydayReminderTitle,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatCurrency(amount)}${note.isNotEmpty ? ' - $note' : ''}',
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(120)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSkipped,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text(AppStrings.paydayReminderNotYet, style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface.withAlpha(150),
                      side: BorderSide(color: colors.onSurface.withAlpha(40)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReceived,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(AppStrings.paydayReminderYes, style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MissedPaydayCard extends StatelessWidget {
  final double amount;
  final String note;
  final VoidCallback? onReceived;

  const _MissedPaydayCard({
    super.key,
    required this.amount,
    required this.note,
    this.onReceived,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_outlined, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.paydayMissedTitle,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                  const SizedBox(height: 2),
                  Text('${formatCurrency(amount)}${note.isNotEmpty ? ' - $note' : ''} ${AppStrings.paydayMissedSubtitle}',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                ],
              ),
            ),
            TextButton(
              onPressed: onReceived,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(AppStrings.paydayMissedCta, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRealityCheck extends StatelessWidget {
  final EnvelopeProvider provider;
  final double trendPercent;
  final int daysUntilPayday;

  const _MoneyRealityCheck({
    super.key,
    required this.provider,
    required this.trendPercent,
    required this.daysUntilPayday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final totalAvailable = provider.calculateTotalBalance();
    final totalAllocated = provider.getTotalAllocatedToEnvelopes();
    final unallocated = provider.getUnallocated();
    final monthlySpent = provider.getTotalSpentThisMonth();
    final lastPayDate = provider.lastPaydayDate;
    final lastPayLabel = lastPayDate != null
        ? DateFormat('d MMM').format(DateTime.parse(lastPayDate))
        : '---';
    final spendingFast = trendPercent > 20;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.onSurface.withAlpha(12),
              colors.onSurface.withAlpha(6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.dashboardRealityCheck,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withAlpha(180))),
                if (daysUntilPayday <= 30)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: daysUntilPayday <= 3 ? Colors.orange.withAlpha(30) : colors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$daysUntilPayday ${AppStrings.dashboardDaysUntilPayday}',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: daysUntilPayday <= 3 ? Colors.orange : colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statBlock(context, AppStrings.dashboardAvailable, formatCurrency(totalAvailable),
                      totalAvailable < 0 ? Colors.redAccent : colors.primary, colors),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBlock(context, AppStrings.dashboardAllocated, formatCurrency(totalAllocated),
                      Colors.amberAccent, colors),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBlock(context, AppStrings.dashboardUnassigned, formatCurrency(unallocated),
                      unallocated > 0 ? Colors.greenAccent : colors.onSurface.withAlpha(100), colors),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _statBlock(context, AppStrings.dashboardSpentMonth, formatCurrency(monthlySpent),
                      Colors.redAccent, colors),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBlock(context, AppStrings.dashboardEnvelopes, '${provider.envelopes.length}',
                      colors.primary, colors),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBlock(context, AppStrings.dashboardLastPay, lastPayLabel,
                      colors.primary, colors),
                ),
              ],
            ),
            if (spendingFast || totalAvailable < 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        spendingFast
                            ? '${AppStrings.dashboardSpendingFaster.replaceAll('%', trendPercent.toStringAsFixed(0))}'
                            : AppStrings.dashboardOverSpent,
                        style: TextStyle(fontSize: 11, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBlock(BuildContext context, String label, String value, Color color, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withAlpha(100))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: color,
        )),
      ],
    );
  }
}
