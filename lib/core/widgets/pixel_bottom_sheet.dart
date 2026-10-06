import 'package:flutter/material.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/widgets/pixel_card.dart';
import 'package:pixelarticons/pixel.dart';

Future<T?> showPixelBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.background.withValues(alpha: 0.72),
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 280),
      curve: Easing.emphasizedDecelerate,
      reverseCurve: FlippedCurve(Easing.emphasizedAccelerate),
    ),
    builder: (context) => ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Builder(builder: builder),
      ),
    ),
  );
}

class PixelBottomSheetFrame extends StatelessWidget {
  const PixelBottomSheetFrame({
    super.key,
    required this.child,
    required this.title,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16 + keyboard + bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.85),
          child: SizedBox(
            width: double.infinity,
            child: PixelCard(
              elevated: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PixelSheetHeader(title: title),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelSheetHeader extends StatelessWidget {
  const _PixelSheetHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s12,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingSmall,
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.s4),
              child: Icon(
                Pixel.close,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
