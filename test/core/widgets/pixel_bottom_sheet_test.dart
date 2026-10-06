import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_sheet.dart';

Widget _host() => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showPixelBottomSheet<void>(
          context: context,
          builder: (_) =>
              const PixelBottomSheetFrame(title: 'SHEET', child: Text('body')),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

ModalBottomSheetRoute<void> _route(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.text('body')))!
        as ModalBottomSheetRoute<void>;

void main() {
  testWidgets('a sheet takes 420ms to open', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pump();
    final route = _route(tester);

    await tester.pump(const Duration(milliseconds: 400));
    expect(route.animation!.status, AnimationStatus.forward);
    await tester.pump(const Duration(milliseconds: 30));
    expect(route.animation!.status, AnimationStatus.completed);
  });

  testWidgets('a sheet takes 280ms to close', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('body'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('body'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('a sheet decelerates in and accelerates out', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pump();

    final style = _route(tester).sheetAnimationStyle!;
    expect(style.curve, Easing.emphasizedDecelerate);
    expect(style.reverseCurve, const FlippedCurve(Easing.emphasizedAccelerate));
  });
}
