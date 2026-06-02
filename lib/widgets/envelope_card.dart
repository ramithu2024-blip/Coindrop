import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/envelope.dart';
import '../providers/envelope_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../utils/constants.dart';
import '../theme/app_theme.dart';

class EnvelopeCard extends StatelessWidget {
  final Envelope envelope;

  const EnvelopeCard({super.key, required this.envelope});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? colors.surface;
    final useCustomColors = context.watch<ThemeProvider>().useCustomEnvelopeColors;

    return Consumer<EnvelopeProvider>(
      builder: (context, provider, _) {
        final remaining = provider.calculateRemaining(envelope.id!);
        final totalFunding = provider.getTotalFunding(envelope.id!);
        final totalSpending = provider.getTotalSpending(envelope.id!);
        final progress = totalFunding > 0
            ? (totalSpending / totalFunding).clamp(0.0, 1.0)
            : 0.0;
        final isOverBudget = remaining < 0;
        final envelopeColor = useCustomColors ? Color(envelope.color) : colors.primary;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          color: cardColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(context, '/envelope-detail',
                  arguments: envelope);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: envelopeColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                EnvelopeIcons.getIcon(envelope.icon),
                                color: envelopeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                envelope.name,
                                style: AppTextStyles.envelopeName(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          formatCurrency(remaining),
                          style: TextStyle(
                            color: isOverBudget
                                ? Colors.redAccent
                                : colors.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor:
                              colors.onSurface.withAlpha(25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget
                                ? Colors.redAccent
                                : envelopeColor,
                          ),
                          minHeight: 6,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Funded ${formatCurrency(totalFunding)}',
                          style: AppTextStyles.bodySmall(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% spent',
                        style: AppTextStyles.bodySmall(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
