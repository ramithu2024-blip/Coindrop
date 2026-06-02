import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/envelope_provider.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../utils/constants.dart';

class PaydayHistoryScreen extends StatefulWidget {
  const PaydayHistoryScreen({super.key});

  @override
  State<PaydayHistoryScreen> createState() => _PaydayHistoryScreenState();
}

class _PaydayHistoryScreenState extends State<PaydayHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnvelopeProvider>().loadEnvelopes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Payday History'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: Consumer<EnvelopeProvider>(
        builder: (context, provider, _) {
          if (provider.paydays.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined, size: 64,
                      color: colors.onSurface.withAlpha(50)),
                  const SizedBox(height: 16),
                  Text('No paydays yet',
                      style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Use "New Payday" to add your first',
                      style: TextStyle(color: colors.onSurface.withAlpha(80), fontSize: 14)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadEnvelopes(),
            color: colors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.paydays.length,
              itemBuilder: (context, index) {
                final payday = provider.paydays[index];
                return _PaydayCard(payday: payday);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PaydayCard extends StatelessWidget {
  final dynamic payday;

  const _PaydayCard({required this.payday});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Consumer<EnvelopeProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<Map<String, dynamic>>(
          future: provider.getPaydayDetails(payday.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: CircularProgressIndicator(color: colors.primary)),
              );
            }

            final details = snapshot.data!;
            final allocated = details['allocated'] as double;
            final remaining = details['remaining'] as double;
            final allocations = details['allocations'] as List<Map<String, dynamic>>;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.onSurface.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                iconColor: colors.onSurface.withAlpha(100),
                collapsedIconColor: colors.onSurface.withAlpha(100),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(payday.note,
                              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(formatDate(payday.date),
                              style: TextStyle(color: colors.onSurface.withAlpha(100), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(formatCurrency(payday.amount),
                        style: TextStyle(color: colors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                children: [
                  Row(
                    children: [
                      _detailChip('Allocated', formatCurrency(allocated), colors.primary, colors),
                      const SizedBox(width: 8),
                      _detailChip('Remaining', formatCurrency(remaining), colors.primary, colors),
                    ],
                  ),
                  if (remaining > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Unallocated: ${formatCurrency(remaining)}',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                    ),
                  if (allocations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Allocations',
                        style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...allocations.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(EnvelopeIcons.getIcon(a['icon'] as String?),
                                  color: Color(a['color'] as int? ?? EnvelopeColors.defaultColor), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(a['envelope_name'] as String,
                                    style: TextStyle(color: colors.onSurface.withAlpha(180))),
                              ),
                              Text(formatCurrency((a['amount'] as num).toDouble()),
                                  style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailChip(String label, String value, Color color, ColorScheme colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.onSurface.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
