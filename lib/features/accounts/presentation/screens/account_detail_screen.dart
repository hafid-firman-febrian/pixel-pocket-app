import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixel_pocket/core/widgets/pixel_card.dart';
import 'package:pixel_pocket/core/widgets/pixel_error_view.dart';
import 'package:pixel_pocket/core/widgets/pixel_snack_bar.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/presentation/controllers/account_history_controller.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/account_amount.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/adjust_balance_sheet.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/dashboard/presentation/states/dashboard_state.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/widgets/transaction_list_item.dart';
import 'package:pixelarticons/pixel.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(accountBalancesProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    final balance = balancesAsync.valueOrNull
        ?.where((b) => b.account.id == accountId)
        .firstOrNull;
    final provider = accountHistoryControllerProvider(accountId);
    final historyAsync = ref.watch(provider);
    final history = ref.read(provider.notifier);

    if (balancesAsync.hasValue && balance == null) {
      return Scaffold(
        body: Center(
          child: Text('Account not found.', style: AppTextStyles.bodyNormal),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.section,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            Row(
              children: [
                PixelIconButton(
                  icon: Pixel.chevronleft,
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    (balance?.account.name ?? '').toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.displayMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            PixelCard(
              elevated: true,
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BALANCE',
                    style: AppTextStyles.bodyNormal.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  if (balance == null)
                    const LinearProgressIndicator()
                  else
                    AccountAmount(
                      value: balance.balance,
                      hidden: hidden,
                      style: AppTextStyles.numericXl,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            PixelButton(
              label: 'ADJUST BALANCE',
              icon: Pixel.edit,
              isFullWidth: true,
              onPressed: balance == null
                  ? null
                  : () => _adjust(context, balance),
            ),
            const SizedBox(height: AppSpacing.section),
            Text('HISTORY', style: AppTextStyles.bodyNormal),
            const SizedBox(height: AppSpacing.s8),
            _History(
              accountId: accountId,
              async: historyAsync,
              hasMore: history.hasMore,
              onLoadMore: () => history.loadMore(),
              onRetry: () => ref.invalidate(provider),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjust(BuildContext context, AccountBalance balance) async {
    final messenger = ScaffoldMessenger.of(context);
    final adjusted = await AdjustBalanceSheet.show(context, balance: balance);
    if (adjusted == true) messenger.showPixelSnackBar('Balance adjusted');
  }
}

class _History extends StatelessWidget {
  const _History({
    required this.accountId,
    required this.async,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
  });

  final int accountId;
  final AsyncValue<List<TransactionModel>> async;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (async.hasError && !async.hasValue) {
      return PixelErrorView(
        failure: asFailure(async.error),
        onRetry: onRetry,
        compact: true,
      );
    }
    final items = async.valueOrNull;
    if (items == null) return const LinearProgressIndicator();
    if (items.isEmpty) {
      return PixelCard(
        padding: AppSpacing.card,
        child: Text(
          'No transactions yet.',
          style: AppTextStyles.bodyNormal.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelCard(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                TransactionListItem(
                  transaction: items[i],
                  perspectiveAccountId: accountId,
                ),
              ],
            ],
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: AppSpacing.s12),
          PixelButton(
            label: 'LOAD MORE',
            variant: PixelButtonVariant.surface,
            isFullWidth: true,
            onPressed: onLoadMore,
          ),
        ],
      ],
    );
  }
}
