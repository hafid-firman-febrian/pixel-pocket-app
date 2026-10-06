import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixelarticons/pixel.dart';

class PixelNavItem {
  const PixelNavItem({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;
}

class PixelBottomNav extends StatelessWidget {
  const PixelBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  final List<PixelNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  static const cursorBlinkInterval = Duration(milliseconds: 530);

  static const double _barHeight = 56;

  @override
  Widget build(BuildContext context) {
    final half = items.length ~/ 2;

    Widget tab(int i) => Expanded(
      child: _PixelNavTab(
        item: items[i],
        isActive: i == currentIndex,
        onTap: () => onTap(i),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: [
              for (var i = 0; i < half; i++) tab(i),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                child: Semantics(
                  container: true,
                  label: 'Add transaction',
                  button: true,
                  excludeSemantics: true,
                  onTap: onAdd,
                  child: PixelButton(icon: Pixel.plus, onPressed: onAdd),
                ),
              ),
              for (var i = half; i < items.length; i++) tab(i),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelNavTab extends StatefulWidget {
  const _PixelNavTab({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final PixelNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_PixelNavTab> createState() => _PixelNavTabState();
}

class _PixelNavTabState extends State<_PixelNavTab> {
  static const double _cursorGap = AppSpacing.s4;
  static const double _cursorSlot = 12;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? AppColors.primary : AppColors.textMuted;

    return Semantics(
      container: true,
      label: widget.item.label,
      button: true,
      selected: widget.isActive,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Tooltip(
        message: widget.item.label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: _cursorGap + _cursorSlot),

                Icon(widget.item.icon, size: 24, color: color),
                const SizedBox(height: _cursorGap),

                SizedBox(
                  height: _cursorSlot,
                  child: widget.isActive ? const _BlinkingCursor() : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  Timer? _timer;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && _timer == null) {
      _timer = Timer.periodic(
        PixelBottomNav.cursorBlinkInterval,
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
      child: Text(
        '_',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
          color: _visible ? AppColors.primary : Colors.transparent,
        ),
      ),
    );
  }
}
