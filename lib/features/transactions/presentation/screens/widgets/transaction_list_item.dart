import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/utils/currency_formatter.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.perspectiveAccountId,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;
  final int? perspectiveAccountId;

  bool get _neutral => transaction.isTransfer || transaction.isAdjustment;

  bool get _hasDescription => transaction.description?.isNotEmpty ?? false;

  String get _route =>
      '${transaction.accountName ?? '?'} → ${transaction.toAccountName ?? '?'}';

  String get _title {
    final tx = transaction;
    if (_hasDescription) return tx.description!;
    if (tx.isTransfer) return _route;
    if (tx.isAdjustment) return 'Adjustment';
    return tx.categoryName ?? 'Uncategorized';
  }

  String? get _subtitle {
    final tx = transaction;
    if (tx.isTransfer) return _hasDescription ? _route : null;
    if (tx.isAdjustment) return tx.accountName;
    final parts = [
      if (_hasDescription && tx.categoryName != null) tx.categoryName!,
      if (tx.accountName != null) tx.accountName!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get _amountText {
    final tx = transaction;
    final value = _thousands(tx.amount.abs());
    if (tx.isAdjustment) return '${tx.amount < 0 ? '-' : '+'}$value';
    if (tx.isTransfer) {
      if (perspectiveAccountId == null) return value;
      return '${perspectiveAccountId == tx.toAccountId ? '+' : '-'}$value';
    }
    return '${tx.isIncome ? '+' : '-'}$value';
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _neutral
        ? AppColors.textMuted
        : AppColors.fromHex(transaction.categoryColor);
    final amountColor = _neutral
        ? AppColors.textPrimary
        : (transaction.isIncome ? AppColors.income : AppColors.expense);
    final subtitle = _subtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: barColor),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyNormal.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        subtitle.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.overlineSm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _amountText,
                    style: AppTextStyles.bodyNormal.copyWith(
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    _formatDate(transaction.transactionDate),
                    style: AppTextStyles.overlineSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _thousands(double amount) {
    final formatted = CurrencyFormatter.input(amount);
    return formatted.isEmpty ? '0' : formatted;
  }

  String _formatDate(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return DateFormat('d MMM').format(parsed).toUpperCase();
  }
}
