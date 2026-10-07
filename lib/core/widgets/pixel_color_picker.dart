import 'package:flutter/material.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';

const List<String> pixelColorPalette = [
  '#7D9B76',
  '#5F8A8B',
  '#8B6355',
  '#8C7B6B',
  '#C4A882',
  '#6B7C8D',
  '#9B6B8C',
  '#B5847A',
  '#CC7358',
  '#A0856C',
  '#7B6D8D',
  '#4A7C8C',
  '#6B8C5F',
  '#5B7A8C',
  '#8C7A3D',
  '#8C5B3D',
  '#7A8C6B',
  '#8C8C7B',
];

class PixelColorPicker extends StatelessWidget {
  const PixelColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.palette = pixelColorPalette,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> palette;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        for (final hex in palette)
          _ColorSwatch(
            key: ValueKey(hex),
            hex: hex,
            selected: hex == selected,
            onTap: () => onChanged(hex),
          ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.fromHex(hex),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
