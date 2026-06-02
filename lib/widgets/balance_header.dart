import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/envelope_provider.dart';
import '../utils/currency.dart';
import '../theme/app_theme.dart';

class BalanceHeader extends StatelessWidget {
  const BalanceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Consumer<EnvelopeProvider>(
      builder: (context, provider, _) {
        final totalBalance = provider.calculateTotalBalance();
        final bankBalance = provider.getBankBalance();
        final envAllocated = provider.getTotalAllocatedToEnvelopes();
        final netWorth = provider.getNetWorth();
        final monthlySpent = provider.getTotalSpentThisMonth();
        final isNegative = totalBalance < 0;

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  colors.primary.withAlpha(35),
                  colors.surface.withAlpha(200),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Balance',
                      style: AppTextStyles.balanceSmall(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.redAccent.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        '${formatCurrency(monthlySpent)} spent',
                        style: TextStyle(
                          color: Colors.redAccent[200],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  formatCurrency(totalBalance),
                  style: TextStyle(
                    color: isNegative
                        ? Colors.redAccent
                        : colors.onSurface,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${provider.envelopes.length} envelopes  ·  ${provider.paydays.length} paydays',
                  style: AppTextStyles.bodySmall(context),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withAlpha(10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.onSurface.withAlpha(15),
                    ),
                  ),
                  child: Column(
                    children: [
                      _balanceRow(
                        context,
                        'Bank',
                        formatCurrency(bankBalance),
                        Icons.account_balance,
                        colors.primary,
                      ),
                      const SizedBox(height: 12),
                      _balanceRow(
                        context,
                        'Envelopes',
                        formatCurrency(envAllocated),
                        Icons.mail_outline,
                        Colors.amberAccent,
                      ),
                      const SizedBox(height: 12),
                      _balanceRow(
                        context,
                        'Net Worth',
                        formatCurrency(netWorth),
                        Icons.monetization_on_outlined,
                        colors.primary,
                      ),
                      if (provider.paydays.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _nextPaydayRow(context, provider, colors),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _balanceRow(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withAlpha(180), size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _nextPaydayRow(
      BuildContext context, EnvelopeProvider provider, ColorScheme colors) {
    String label;
    double amount;
    if (provider.paydays.isNotEmpty) {
      final last = provider.paydays.first;
      label = 'Last Payday';
      amount = last.amount;
    } else {
      label = 'No payday';
      amount = 0.0;
    }
    return Row(
      children: [
        Icon(
          Icons.payments_outlined,
          color: colors.primary.withAlpha(180),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: colors.onSurface.withAlpha(150),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          amount > 0 ? '+${formatCurrency(amount)}' : '---',
          style: TextStyle(
            color: colors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
