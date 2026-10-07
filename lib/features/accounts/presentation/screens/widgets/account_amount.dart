import 'package:flutter/material.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/utils/currency_formatter.dart';

const _mask = '******';

class AccountAmount extends StatelessWidget {
  const AccountAmount({
    super.key,
    required this.value,
    required this.hidden,
    this.style,
  });

  final double value;
  final bool hidden;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final negative = !hidden && value < 0;
    final base =
        style ?? AppTextStyles.bodyNormal.copyWith(fontWeight: FontWeight.w900);
    return Text(
      hidden
          ? 'Rp $_mask'
          : '${negative ? '-' : ''}${CurrencyFormatter.format(value)}',
      style: base.copyWith(
        color: negative ? AppColors.expense : AppColors.textPrimary,
      ),
    );
  }
}
