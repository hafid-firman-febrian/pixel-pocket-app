import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';

class PinPrompt extends StatelessWidget {
  const PinPrompt({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
    this.enabled = true,
  });

  static const cursorBlinkInterval = Duration(milliseconds: 530);

  final int length;
  final int filled;
  final bool error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1,
      color: !enabled
          ? AppColors.textMuted
          : error
          ? AppColors.expense
          : AppColors.textPrimary,
    );
    return Row(
      children: [
        Text(
          'PIN:',
          style: style?.copyWith(
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        SizedBox(width: AppSpacing.s12),
        for (var i = 0; i < length; i++)
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: i < filled
                  ? Text('■', style: style)
                  : i == filled && enabled
                  ? const _BlinkingBlock()
                  : Text('_', style: style),
            ),
          ),
      ],
    );
  }
}

class _BlinkingBlock extends StatefulWidget {
  const _BlinkingBlock();

  @override
  State<_BlinkingBlock> createState() => _BlinkingBlockState();
}

class _BlinkingBlockState extends State<_BlinkingBlock> {
  Timer? _timer;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && _timer == null) {
      _timer = Timer.periodic(
        PinPrompt.cursorBlinkInterval,
        (_) => setState(() => _visible = !_visible),
      );
    } else if (!animate && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _visible = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 11,
        height: 18,
        color: _visible ? AppColors.primary : Colors.transparent,
      ),
    );
  }
}
