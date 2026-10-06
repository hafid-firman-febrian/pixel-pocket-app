import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';

class PixelPinPad extends StatelessWidget {
  const PixelPinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;

  final VoidCallback onBackspace;

  final bool enabled;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'DEL'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s6,
                  ),
                  child: _key(key),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _key(String key) {
    if (key.isEmpty) return const SizedBox(height: _PinKey.height);
    if (key == 'DEL') {
      return _PinKey(
        label: key,
        danger: true,
        onTap: enabled ? onBackspace : null,
      );
    }
    return _PinKey(label: key, onTap: enabled ? () => onDigit(key) : null);
  }
}

class _PinKey extends StatefulWidget {
  const _PinKey({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  static const height = 52.0;

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final accent = widget.danger ? AppColors.expense : AppColors.primary;
    final idleLabel = widget.danger
        ? AppColors.expense
        : AppColors.textSecondary;
    final pressedLabel = widget.danger ? Colors.white : AppColors.textDark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              HapticFeedback.lightImpact();
              _setPressed(true);
            }
          : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      child: Container(
        height: _PinKey.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed ? accent : Colors.transparent,
          border: Border.all(
            color: widget.danger ? AppColors.expense : AppColors.border,
          ),
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            fontWeight: _pressed ? FontWeight.w700 : FontWeight.w400,
            color: _pressed ? pressedLabel : idleLabel,
          ),
        ),
      ),
    );
  }
}
