import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/router/app_router.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_sizing.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixel_pocket/core/widgets/pixel_card.dart';
import 'package:pixel_pocket/core/widgets/pixel_error_view.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/account_amount.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/account_form_sheet.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/dashboard/presentation/states/dashboard_state.dart';
import 'package:pixelarticons/pixel.dart';

class AccountsCard extends ConsumerWidget {
  const AccountsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountBalancesProvider);
    final hidden = ref.watch(balanceHiddenProvider);

    if (async.hasError && !async.hasValue) {
      return PixelErrorView(
        failure: asFailure(async.error),
        onRetry: () => ref.invalidate(accountBalancesProvider),
        compact: true,
      );
    }
    final items = async.valueOrNull;
    if (items == null) {
      return const SizedBox(
        width: double.infinity,
        child: PixelCard(
          padding: AppSpacing.card,
          child: LinearProgressIndicator(),
        ),
      );
    }
    final active = items.where((b) => !b.account.isArchived).toList();
    if (active.isEmpty) {
      return _EmptyAccounts(onAdd: () => AccountFormSheet.show(context));
    }
    final total = active.fold<double>(0, (sum, b) => sum + b.balance);

    return SizedBox(
      width: double.infinity,
      child: PixelCard(
        child: Column(
          children: [
            for (final b in active) ...[
              _AccountRow(
                name: b.account.name,
                color: AppColors.fromHex(b.account.color),
                balance: b.balance,
                hidden: hidden,
                onTap: () =>
                    context.push(AppRoutes.accountDetailPath(b.account.id)),
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
            _AccountRow(
              name: 'Total',
              balance: total,
              hidden: hidden,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.balance,
    required this.hidden,
    this.color,
    this.onTap,
    this.bold = false,
  });

  final String name;
  final double balance;
  final bool hidden;
  final Color? color;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            if (color != null) ...[
              Container(width: 10, height: 10, color: color),
              const SizedBox(width: AppSpacing.s8),
            ],
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: bold ? AppTextStyles.bodyBold : AppTextStyles.bodyNormal,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            AccountAmount(value: balance, hidden: hidden),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.s4),
              const Icon(
                Pixel.chevronright,
                size: AppSizing.iconSm,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PixelCard(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No accounts yet',
              style: AppTextStyles.bodyNormal.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            PixelButton(
              label: 'ADD ACCOUNT',
              icon: Pixel.plus,
              isFullWidth: true,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
