import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/envelope_provider.dart';
import '../utils/currency.dart';
import '../utils/constants.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>>? _weeklyData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final provider = context.read<EnvelopeProvider>();
    final analytics = await provider.getAnalytics();
    final weekly = await provider.getWeeklySpending(4);
    if (mounted) {
      setState(() {
        _analytics = analytics;
        _weeklyData = weekly;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final spendingByEnv = _analytics!['spendingByEnvelope'] as List<Map<String, dynamic>>;
    final hasData = spendingByEnv.any((e) => (e['total'] as num) > 0);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: colors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(colors),
            const SizedBox(height: 20),
            if (hasData) ...[
              _buildSectionTitle('Spending by Envelope', colors),
              const SizedBox(height: 12),
              _buildPieChart(spendingByEnv, colors),
              const SizedBox(height: 24),
              _buildSectionTitle('Weekly Spending (4 weeks)', colors),
              const SizedBox(height: 12),
              _buildBarChart(colors),
            ] else
              _buildEmptyState(colors),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colors) {
    return Text(title, style: TextStyle(
      color: colors.onSurface, fontSize: 17, fontWeight: FontWeight.w600,
    ));
  }

  Widget _buildStatsRow(ColorScheme colors) {
    final totalSpent = _analytics!['totalSpentThisMonth'] as double;
    final avg = _analytics!['averageSpend'] as double;
    final count = _analytics!['transactionCount'] as int;
    final largest = _analytics!['largestEnvelope'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary.withAlpha(40), colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Month', style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statItem('Spent', formatCurrency(totalSpent), Colors.redAccent, colors)),
              Expanded(child: _statItem('Avg', formatCurrency(avg), colors.primary, colors)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statItem('Transactions', '$count', Colors.amberAccent, colors)),
              Expanded(child: _statItem('Top Envelope', largest, Colors.cyanAccent, colors)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> data, ColorScheme colors) {
    final nonZero = data.where((e) => (e['total'] as num) > 0).toList();
    if (nonZero.isEmpty) return _buildEmptyState(colors);

    final total = nonZero.fold<double>(0, (s, e) => s + (e['total'] as num).toDouble());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: nonZero.map((e) {
                  final amount = (e['total'] as num).toDouble();
                  final pct = total > 0 ? (amount / total * 100) : 0.0;
                  final colorVal = e['color'] as int? ?? EnvelopeColors.defaultColor;
                  return PieChartSectionData(
                    color: Color(colorVal),
                    value: amount,
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 60,
                    titleStyle: TextStyle(
                      color: colors.surface,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: nonZero.map((e) {
              final colorVal = e['color'] as int? ?? EnvelopeColors.defaultColor;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: Color(colorVal), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 6),
                  Text(e['name'] as String, style: TextStyle(color: colors.onSurface.withAlpha(150), fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(ColorScheme colors) {
    if (_weeklyData == null || _weeklyData!.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: colors.onSurface.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(child: Text('No weekly data', style: TextStyle(color: colors.onSurface.withAlpha(100)))),
      );
    }

    final maxY = _weeklyData!.fold<double>(
      0,
      (s, e) => (e['total'] as num).toDouble() > s ? (e['total'] as num).toDouble() : s,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(formatCurrency(rod.toY),
                    TextStyle(color: colors.onSurface, fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _weeklyData!.length) return const SizedBox.shrink();
                    final day = _weeklyData![idx]['day'] as String;
                    final date = DateTime.tryParse(day);
                    if (date == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${date.month}/${date.day}',
                        style: TextStyle(color: colors.onSurface.withAlpha(100), fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 4 : 1,
              getDrawingHorizontalLine: (_) => FlLine(
                color: colors.onSurface.withAlpha(20),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: _weeklyData!.asMap().entries.map((entry) {
              final amount = (entry.value['total'] as num).toDouble();
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: amount,
                    color: colors.primary,
                    width: 14,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 48, color: colors.onSurface.withAlpha(50)),
          const SizedBox(height: 12),
          Text('No spending data yet', style: TextStyle(color: colors.onSurface.withAlpha(120), fontSize: 16)),
          const SizedBox(height: 4),
          Text('Add transactions to see insights', style: TextStyle(color: colors.onSurface.withAlpha(80), fontSize: 13)),
        ],
      ),
    );
  }
}
