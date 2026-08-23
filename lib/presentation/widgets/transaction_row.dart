import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/transaction_record.dart';
import '../../core/utils/formatters.dart';
import 'brand_avatar.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.transaction,
    super.key,
    this.onTap,
    this.compact = false,
  });

  final TransactionRecord transaction;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color amountColor = transaction.isIncome ? AppColors.sage : theme.colorScheme.onSurface;
    final Color muted = AppColors.muted(theme.brightness);
    final String typeLabel = transaction.isIncome ? 'Gelir' : 'Gider';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 11 : 14, horizontal: 2),
          child: Row(
            children: <Widget>[
              BrandAvatar(name: transaction.title, category: transaction.category, size: compact ? 40 : 44),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$typeLabel · ${transaction.category} · ${Formatters.relativeDate(transaction.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Formatters.money(transaction.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: amountColor,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  letterSpacing: -0.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
