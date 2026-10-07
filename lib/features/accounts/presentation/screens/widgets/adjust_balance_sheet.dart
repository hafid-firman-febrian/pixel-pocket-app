import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/utils/currency_formatter.dart';
import 'package:pixel_pocket/core/utils/thousands_input_formatter.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_sheet.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixel_pocket/core/widgets/pixel_field_label.dart';
import 'package:pixel_pocket/core/widgets/pixel_snack_bar.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/presentation/controllers/account_controller.dart';

class AdjustBalanceSheet extends ConsumerStatefulWidget {
  const AdjustBalanceSheet({super.key, required this.balance});

  final AccountBalance balance;

  static Future<bool?> show(
    BuildContext context, {
    required AccountBalance balance,
  }) {
    return showPixelBottomSheet<bool>(
      context: context,
      builder: (_) => AdjustBalanceSheet(balance: balance),
    );
  }

  @override
  ConsumerState<AdjustBalanceSheet> createState() => _AdjustBalanceSheetState();
}

class _AdjustBalanceSheetState extends ConsumerState<AdjustBalanceSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.balance.balance;
    _controller = TextEditingController(
      text: current > 0 ? CurrencyFormatter.input(current) : '0',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _signed(double value, {bool plus = false}) {
    final sign = value < 0 ? '-' : (plus ? '+' : '');
    return '$sign${CurrencyFormatter.format(value)}';
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(accountControllerProvider).adjustBalance(
            accountId: widget.balance.account.id,
            actualBalance: CurrencyFormatter.parse(_controller.text),
          );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = e is Failure ? e.message : 'Failed to adjust balance';
      messenger.showPixelSnackBar(message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PixelBottomSheetFrame(
      title: 'ADJUST BALANCE',
      child: SingleChildScrollView(
        padding: AppSpacing.form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PixelFieldLabel('CURRENT BALANCE'),
            Text(
              _signed(widget.balance.balance),
              style: AppTextStyles.numericMd,
            ),
            const SizedBox(height: AppSpacing.section),
            const PixelFieldLabel('ACTUAL BALANCE'),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
              style: AppTextStyles.numericMd,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final diff =
                    CurrencyFormatter.parse(value.text) - widget.balance.balance;
                return Text(
                  diff == 0
                      ? 'No change'
                      : 'Difference: ${_signed(diff, plus: true)}',
                  style: AppTextStyles.bodyNormal.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s24),
            PixelButton(
              label: 'SAVE',
              isFullWidth: true,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.s12),
            PixelButton(
              label: 'CANCEL',
              variant: PixelButtonVariant.secondary,
              isFullWidth: true,
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
