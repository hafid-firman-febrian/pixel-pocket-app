import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixelarticons/pixel.dart';

// ─────────────────────────────────────────────
// Model satu tab
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// Floating bottom nav — icon-only tabs, a blinking terminal cursor under the
// active one, and the add-transaction button in the middle.
// ─────────────────────────────────────────────
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

  /// How long the active tab's cursor stays on (and then off) per blink.
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s14,
        0,
        AppSpacing.s14,
        AppSpacing.s12 + MediaQuery.paddingOf(context).bottom,
      ),
      // Blur only what sits behind the bar itself, not the whole screen.
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: _barHeight,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                for (var i = 0; i < half; i++) tab(i),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                  ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Satu tab — icon + slot kursor, ikon "tenggelam" 2px saat ditekan
// ─────────────────────────────────────────────
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
                Icon(widget.item.icon, size: 20, color: color),
                const SizedBox(height: AppSpacing.s4),
                // Reserved on every tab so icons don't shift when the active
                // tab changes.
                SizedBox(
                  height: 12,
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

// ─────────────────────────────────────────────
// Kursor terminal `_` di bawah tab aktif
// ─────────────────────────────────────────────

/// Blinks with a stepped on/off [Timer] (≈2 redraws per second) instead of an
/// AnimationController, which would redraw — and re-run the bar's blur —
/// every frame. Stays solid when the OS asks to reduce motion.
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
