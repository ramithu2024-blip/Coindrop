import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../models/transaction.dart' as model;
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../widgets/transaction_tile.dart';
import 'edit_envelope_screen.dart';

enum TransactionFilter { today, week, month, all }

class EnvelopeDetailScreen extends StatefulWidget {
  const EnvelopeDetailScreen({super.key});

  @override
  State<EnvelopeDetailScreen> createState() => _EnvelopeDetailScreenState();
}

class _EnvelopeDetailScreenState extends State<EnvelopeDetailScreen> {
  TransactionFilter _filter = TransactionFilter.all;
  bool _searching = false;
  final _searchController = TextEditingController();
  List<model.Transaction> _filteredTransactions = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Envelope get _envelope =>
      ModalRoute.of(context)!.settings.arguments as Envelope;

  DateTime? get _filterStart {
    final now = DateTime.now();
    switch (_filter) {
      case TransactionFilter.today:
        return DateTime(now.year, now.month, now.day);
      case TransactionFilter.week:
        return now.subtract(Duration(days: now.weekday - 1));
      case TransactionFilter.month:
        return DateTime(now.year, now.month, 1);
      case TransactionFilter.all:
        return null;
    }
  }

  DateTime? get _filterEnd {
    final now = DateTime.now();
    switch (_filter) {
      case TransactionFilter.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case TransactionFilter.week:
        final end = now.subtract(Duration(days: now.weekday - 1)).add(const Duration(days: 6));
        return DateTime(end.year, end.month, end.day, 23, 59, 59);
      case TransactionFilter.month:
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case TransactionFilter.all:
        return null;
    }
  }

  Future<void> _applyFilter() async {
    final provider = context.read<EnvelopeProvider>();
    final start = _filterStart;
    final end = _filterEnd;

    List<model.Transaction> result;
    if (_searching && _searchController.text.isNotEmpty) {
      final all = await provider.searchTransactions(_searchController.text);
      result = all.where((t) => t.envelopeId == _envelope.id).toList();
    } else if (start != null && end != null) {
      result = await provider.getFilteredTransactions(_envelope.id!, start, end);
    } else {
      result = provider.getTransactions(_envelope.id!);
    }

    if (mounted) setState(() => _filteredTransactions = result);
  }

  void _addMoney() {
    final provider = context.read<EnvelopeProvider>();
    final unallocated = provider.getUnallocated();

    if (!provider.hasMoney || unallocated <= 0) {
      showDialog(
        context: context,
        builder: (ctx) {
          final c = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: Text('No Available Money',
                style: TextStyle(color: c.onSurface)),
            content: Text(
              'No available money to allocate. Add a payday first.',
              style: TextStyle(color: c.onSurface.withAlpha(120)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        final amountController = TextEditingController();
        return AlertDialog(
          title: Text('Add Money',
              style: TextStyle(color: c.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add funds to ${_envelope.name}',
                style: TextStyle(color: c.onSurface.withAlpha(120), fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${formatCurrency(unallocated)}',
                style: TextStyle(color: c.primary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    TextInputType.numberWithOptions(decimal: true),
                style:
                    TextStyle(color: c.onSurface, fontSize: 24),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle:
                      TextStyle(color: c.primary, fontSize: 20),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: c.onSurface.withAlpha(80)),
                  filled: true,
                  fillColor: c.onSurface.withAlpha(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim());
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid amount'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (amt > unallocated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Only ${formatCurrency(unallocated)} available'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                provider.addFunding(
                    _envelope.id!, amt, 'Added money');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Added ${formatCurrency(amt)} to ${_envelope.name}'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text('Add',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = colors.onSurface.withAlpha(10);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_envelope.name),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: colors.onSurface.withAlpha(120)),
            onPressed: () => setState(() => _searching = !_searching),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colors.onSurface.withAlpha(120)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<EnvelopeProvider>(),
                    child: EditEnvelopeScreen(envelope: _envelope),
                  ),
                ),
              );
              if (mounted) context.read<EnvelopeProvider>().loadEnvelopes();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Consumer<EnvelopeProvider>(
        builder: (context, provider, _) {
          final remaining = provider.calculateRemaining(_envelope.id!);
          final totalFunding = provider.getTotalFunding(_envelope.id!);
          final totalSpending = provider.getTotalSpending(_envelope.id!);
          final allTransactions = provider.getTransactions(_envelope.id!);
          final isOverBudget = remaining < 0;
          final lowBudget = !isOverBudget && totalFunding > 0 &&
              (remaining / totalFunding) < 0.2;
          final displayTransactions = _filteredTransactions.isEmpty && !_searching
              ? allTransactions
              : _filteredTransactions;
          final useCustomColors = context.watch<ThemeProvider>().useCustomEnvelopeColors;

          return Column(
            children: [
              if (_searching) _buildSearchBar(colors, cardColor),
              _buildBalanceHeader(remaining, totalFunding, totalSpending, isOverBudget, lowBudget, colors, useCustomColors),
              _buildFilterChips(colors),
              if (lowBudget && !isOverBudget)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text('Less than 20% remaining', style: TextStyle(color: Colors.orange, fontSize: 13)),
                    ],
                  ),
                ),
              _buildInsights(remaining, totalFunding, provider, colors),
              _buildQuickActions(colors),
              Expanded(
                child: displayTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: colors.onSurface.withAlpha(80)),
                            const SizedBox(height: 12),
                            Text(
                              _searching ? 'No matching transactions' : 'No transactions yet',
                              style: TextStyle(color: colors.onSurface.withAlpha(100), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: displayTransactions.length,
                        itemBuilder: (context, index) {
                          return TransactionTile(
                            transaction: displayTransactions[index],
                            onDelete: (t) => _deleteTransaction(t, provider),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'addmoney',
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            onPressed: _addMoney,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'spend',
            onPressed: () {
              Navigator.pushNamed(context, '/add-transaction', arguments: _envelope);
            },
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            icon: const Icon(Icons.remove),
            label: const Text('Spend'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colors, Color cardColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colors.onSurface),
        decoration: InputDecoration(
          hintText: 'Search by note...',
          hintStyle: TextStyle(color: colors.onSurface.withAlpha(100)),
          prefixIcon: Icon(Icons.search, color: colors.onSurface.withAlpha(120)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colors.onSurface.withAlpha(120)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _filteredTransactions = []);
                    _applyFilter();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onSubmitted: (_) => _applyFilter(),
        onChanged: (v) {
          if (v.isEmpty) setState(() => _filteredTransactions = []);
        },
      ),
    );
  }

  Widget _buildBalanceHeader(double remaining, double totalFunding, double totalSpending,
      bool isOverBudget, bool lowBudget, ColorScheme colors, bool useCustomColors) {
    final envelopeColor = useCustomColors ? Color(_envelope.color) : colors.primary;
    final pct = totalFunding > 0 ? (totalSpending / totalFunding).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [envelopeColor.withAlpha(50), envelopeColor.withAlpha(20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: envelopeColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remaining', style: TextStyle(color: colors.onSurface.withAlpha(150), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(remaining),
                    style: TextStyle(
                      color: isOverBudget ? Colors.redAccent : colors.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Funded', style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12)),
                  Text(
                    formatCurrency(totalFunding),
                    style: TextStyle(color: colors.primary, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          if (totalSpending > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: colors.onSurface.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget ? Colors.redAccent : envelopeColor,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${formatCurrency(totalSpending)} spent',
                    style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12)),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: TransactionFilter.values.map((f) {
          final selected = _filter == f;
          return GestureDetector(
            onTap: () {
              setState(() => _filter = f);
              _applyFilter();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.onSurface.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f.name.toUpperCase(),
                style: TextStyle(
                  color: selected ? colors.onPrimary : colors.onSurface.withAlpha(120),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Quick: ', style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12)),
          ...[5, 10, 20, 50].map((amount) => ActionChip(
            label: Text('+\$$amount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            backgroundColor: colors.onSurface.withAlpha(20),
            labelStyle: TextStyle(color: colors.onSurface),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.primary.withAlpha(60)),
            ),
            onPressed: () => _quickSpend(amount.toDouble()),
          )),
        ],
      ),
    );
  }

  Widget _buildInsights(double remaining, double totalFunding, EnvelopeProvider provider, ColorScheme colors) {
    final avgDaily = provider.getAverageDailySpend(_envelope.id!);
    final daysLeft = provider.getDaysUntilDepleted(_envelope.id!);
    if (avgDaily <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, size: 18, color: colors.primary.withAlpha(180)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avg \$${avgDaily.toStringAsFixed(0)}/day  ·  ${daysLeft >= 999 ? '∞' : '$daysLeft days'} until depleted',
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withAlpha(170)),
                ),
                if (daysLeft < 14)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      daysLeft <= 7 ? '⚠️ Running out this week' : '⚠️ Running out in $daysLeft days',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _quickSpend(double amount) {
    final remaining = context.read<EnvelopeProvider>().calculateRemaining(_envelope.id!);
    if (amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount exceeds remaining balance!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Quick Spend', style: TextStyle(color: c.onSurface)),
          content: Text(
            'Spend ${formatCurrency(amount)} from ${_envelope.name}?',
            style: TextStyle(color: c.onSurface.withAlpha(120)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final transaction = model.Transaction(
                  envelopeId: _envelope.id!,
                  amount: amount,
                  note: 'Quick spend',
                  date: DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now()),
                  type: 'spending',
                );
                context.read<EnvelopeProvider>().addTransaction(transaction);
              },
              child: const Text('Spend', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Delete Envelope', style: TextStyle(color: c.onSurface)),
          content: Text(
            'This will delete the envelope and all its transactions.',
            style: TextStyle(color: c.onSurface.withAlpha(120)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<EnvelopeProvider>().deleteEnvelope(_envelope.id!).then((_) {
                  if (mounted) Navigator.pop(context);
                });
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _deleteTransaction(model.Transaction transaction, EnvelopeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Delete Transaction', style: TextStyle(color: c.onSurface)),
          content: Text('This action cannot be undone.', style: TextStyle(color: c.onSurface.withAlpha(120))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.deleteTransaction(transaction.id!, transaction.envelopeId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }
}
