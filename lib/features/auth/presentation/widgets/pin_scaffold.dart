import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/features/auth/presentation/widgets/pin_prompt.dart';
import 'package:pixel_pocket/features/auth/presentation/widgets/pixel_pin_pad.dart';

class PinLine {
  const PinLine(this.text) : error = false;

  const PinLine.error(this.text) : error = true;

  final String text;
  final bool error;
}

class PinScaffold extends StatefulWidget {
  const PinScaffold({
    super.key,
    required this.lines,
    required this.length,
    required this.filled,
    required this.onDigit,
    required this.onBackspace,
    this.error = false,
    this.keypadEnabled = true,
    this.footer,
  });

  final List<PinLine> lines;
  final int length;
  final int filled;

  final bool error;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  final bool keypadEnabled;

  final Widget? footer;

  @override
  State<PinScaffold> createState() => _PinScaffoldState();
}

class _PinScaffoldState extends State<PinScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(PinScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error) {
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  double _shakeOffset(double t) => sin(t * pi * 4) * 12 * (1 - t);

  @override
  Widget build(BuildContext context) {
    final lineStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.7,
      color: AppColors.textSecondary,
    );
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: AppSpacing.screenAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AppSpacing.s24),
                  Text(
                    'PIXEL_POCKET',
                    style: lineStyle?.copyWith(color: AppColors.textMuted),
                  ),
                  SizedBox(height: AppSpacing.s4),
                  Container(height: 1, color: AppColors.border),
                  SizedBox(height: AppSpacing.s8),
                  for (final line in widget.lines) _line(line, lineStyle),
                  SizedBox(height: AppSpacing.s16),
                  AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeOffset(_shake.value), 0),
                      child: child,
                    ),
                    child: PinPrompt(
                      length: widget.length,
                      filled: widget.filled,
                      error: widget.error,
                      enabled: widget.keypadEnabled,
                    ),
                  ),
                  if (widget.footer != null) ...[
                    SizedBox(height: AppSpacing.s16),
                    widget.footer!,
                  ],
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: widget.keypadEnabled ? 1 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: PixelPinPad(
                      onDigit: widget.onDigit,
                      onBackspace: widget.onBackspace,
                      enabled: widget.keypadEnabled,
                    ),
                  ),
                  SizedBox(height: AppSpacing.s16),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _ScanlinePainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(PinLine line, TextStyle? style) {
    if (line.error) {
      return Text(
        '> ${line.text}',
        style: style?.copyWith(
          color: AppColors.expense,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: '> ',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: line.text),
        ],
      ),
      style: style,
    );
  }
}

class PinLink extends StatelessWidget {
  const PinLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
          child: Text(
            '> [ $label ]',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x38000000);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}
