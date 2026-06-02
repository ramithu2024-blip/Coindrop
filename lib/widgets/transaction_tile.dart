import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../theme/app_theme.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final void Function(Transaction)? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? colors.surface;
    final isFunding = transaction.isFunding;
    final color = isFunding ? colors.primary : Colors.redAccent;
    final icon = isFunding ? Icons.arrow_downward : Icons.arrow_upward;

    return Dismissible(
      key: Key('txn_${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => onDelete != null,
      onDismissed: (_) {
        if (onDelete != null) onDelete!(transaction);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFunding ? 'FUND' : 'SPEND',
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          transaction.note,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDateShort(transaction.date),
                    style: AppTextStyles.bodySmall(context),
                  ),
                ],
              ),
            ),
            Text(
              '${isFunding ? '+' : '-'}${formatCurrency(transaction.amount)}',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
