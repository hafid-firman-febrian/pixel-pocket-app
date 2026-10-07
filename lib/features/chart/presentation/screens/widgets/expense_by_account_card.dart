import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/utils/currency_formatter.dart';
import 'package:pixel_pocket/core/widgets/pixel_card.dart';
import 'package:pixel_pocket/core/widgets/pixel_error_view.dart';
import 'package:pixel_pocket/features/chart/domain/models/account_expense.dart';
import 'package:pixel_pocket/features/chart/presentation/states/chart_state.dart';

class ExpenseByAccountSection extends ConsumerWidget {
  const ExpenseByAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseByAccountProvider);
    if (async.hasError && !async.hasValue) {
      return PixelErrorView(
        failure: asFailure(async.error),
        onRetry: () => ref.invalidate(expenseByAccountProvider),
        compact: true,
      );
    }
    final items = async.valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.section),
        Text('EXPENSE BY ACCOUNT', style: AppTextStyles.bodyNormal),
        const SizedBox(height: AppSpacing.section),
        ExpenseByAccountCard(items: items),
      ],
    );
  }
}

class ExpenseByAccountCard extends StatelessWidget {
  const ExpenseByAccountCard({super.key, required this.items});

  final List<AccountExpense> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PixelCard(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.section),
                _AccountExpenseRow(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountExpenseRow extends StatelessWidget {
  const _AccountExpenseRow({required this.item});

  final AccountExpense item;

  @override
  Widget build(BuildContext context) {
    final color = item.hasAccount
        ? AppColors.fromHex(item.colorHex)
        : AppColors.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyNormal,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              CurrencyFormatter.format(item.total),
              style: AppTextStyles.bodyNormal.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    Container(color: AppColors.border),
                    FractionallySizedBox(
                      widthFactor: (item.percentage / 100).clamp(0.0, 1.0),
                      child: Container(color: color),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              '${item.percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.overlineSm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
