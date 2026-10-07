import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/widgets/pixel_color_picker.dart';

void main() {
  testWidgets('tapping a swatch reports its hex', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PixelColorPicker(
            selected: pixelColorPalette.first,
            onChanged: (hex) => picked = hex,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey(pixelColorPalette[3])));
    expect(picked, pixelColorPalette[3]);
  });

  testWidgets('shows the palette it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PixelColorPicker(
            palette: const ['#386694', '#4791C2'],
            selected: '#386694',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('#386694')), findsOneWidget);
    expect(find.byKey(const ValueKey('#4791C2')), findsOneWidget);
    expect(find.byKey(ValueKey(pixelColorPalette.first)), findsNothing);
  });
}
