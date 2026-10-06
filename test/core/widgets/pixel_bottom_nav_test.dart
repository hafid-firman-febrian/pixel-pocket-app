import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_nav.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixelarticons/pixel.dart';

const _items = [
  PixelNavItem(icon: Pixel.home, label: 'HOME', path: '/'),
  PixelNavItem(icon: Pixel.reciept, label: 'TXN', path: '/transactions'),
  PixelNavItem(icon: Pixel.chartbar, label: 'CHART', path: '/chart'),
  PixelNavItem(icon: Pixel.sliders, label: 'SETTINGS', path: '/settings'),
];

Widget _host({
  int currentIndex = 0,
  ValueChanged<int>? onTap,
  VoidCallback? onAdd,
  bool disableAnimations = false,
  Widget body = const SizedBox.expand(),
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: PixelBottomNav(
        items: _items,
        currentIndex: currentIndex,
        onTap: onTap ?? (_) {},
        onAdd: onAdd ?? () {},
      ),
    ),
  );
}

final _cursor = find.text('_');

Color? _cursorColor(WidgetTester tester) =>
    tester.widget<Text>(_cursor).style?.color;

void main() {
  group('PixelBottomNav', () {
    testWidgets('two tabs, the + button, then two tabs', (tester) async {
      await tester.pumpWidget(_host());
      final txn = tester.getCenter(find.byTooltip('TXN')).dx;
      final add = tester.getCenter(find.byType(PixelButton)).dx;
      final chart = tester.getCenter(find.byTooltip('CHART')).dx;
      expect(find.byType(PixelButton), findsOneWidget);
      expect(txn, lessThan(add));
      expect(add, lessThan(chart));
    });

    testWidgets('labels are not drawn, only offered as tooltips',
        (tester) async {
      await tester.pumpWidget(_host());
      expect(find.text('HOME'), findsNothing);
      expect(find.byTooltip('HOME'), findsOneWidget);
    });

    testWidgets('tapping a tab reports its index', (tester) async {
      int? tapped;
      await tester.pumpWidget(_host(onTap: (i) => tapped = i));
      await tester.tap(find.byTooltip('CHART'));
      expect(tapped, 2);
    });

    testWidgets('tapping + calls onAdd', (tester) async {
      var added = 0;
      await tester.pumpWidget(_host(onAdd: () => added++));
      await tester.tap(find.byType(PixelButton));
      expect(added, 1);
    });

    testWidgets('long-press shows the label without switching tabs',
        (tester) async {
      int? tapped;
      await tester.pumpWidget(_host(onTap: (i) => tapped = i));
      await tester.longPress(find.byTooltip('CHART'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('CHART'), findsOneWidget);
      expect(tapped, isNull);
    });

    testWidgets('screen readers get labels and only the active tab is selected',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(currentIndex: 1));
      expect(
        tester.getSemantics(find.bySemanticsLabel('TXN')),
        isSemantics(label: 'TXN', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('HOME')),
        isSemantics(label: 'HOME', isButton: true, isSelected: false),
      );
      expect(find.bySemanticsLabel('Add transaction'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the cursor sits only under the active tab', (tester) async {
      await tester.pumpWidget(_host(currentIndex: 1));
      expect(_cursor, findsOneWidget);
      expect(
        find.descendant(of: find.byTooltip('TXN'), matching: _cursor),
        findsOneWidget,
      );
    });

    testWidgets('the cursor blinks in on/off steps', (tester) async {
      await tester.pumpWidget(_host());
      expect(_cursorColor(tester), AppColors.primary);
      await tester.pump(PixelBottomNav.cursorBlinkInterval);
      expect(_cursorColor(tester), Colors.transparent);
      await tester.pump(PixelBottomNav.cursorBlinkInterval);
      expect(_cursorColor(tester), AppColors.primary);
    });

    testWidgets('switching tabs restarts the cursor in its on state',
        (tester) async {
      await tester.pumpWidget(_host(currentIndex: 0));
      await tester.pump(PixelBottomNav.cursorBlinkInterval);
      expect(_cursorColor(tester), Colors.transparent);

      await tester.pumpWidget(_host(currentIndex: 1));
      expect(
        find.descendant(of: find.byTooltip('TXN'), matching: _cursor),
        findsOneWidget,
      );
      expect(_cursorColor(tester), AppColors.primary);
    });

    testWidgets('reduce motion keeps the cursor solid', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: true));
      for (var i = 0; i < 3; i++) {
        await tester.pump(PixelBottomNav.cursorBlinkInterval);
        expect(_cursorColor(tester), AppColors.primary);
      }
    });

    testWidgets('turning reduce motion on mid-blink stops the cursor solid',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(PixelBottomNav.cursorBlinkInterval);
      expect(_cursorColor(tester), Colors.transparent);

      await tester.pumpWidget(_host(disableAnimations: true));
      expect(_cursorColor(tester), AppColors.primary);
      await tester.pump(PixelBottomNav.cursorBlinkInterval);
      expect(_cursorColor(tester), AppColors.primary);
    });

    testWidgets('a floating snackbar from a nested Scaffold clears the bar',
        (tester) async {
      await tester.pumpWidget(
        _host(
          // Tab screens are Scaffolds nested inside AppShell's Scaffold.
          body: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saved'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  child: const Text('show'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();

      final snack = tester.getRect(find.byType(SnackBar));
      final nav = tester.getRect(find.byType(PixelBottomNav));
      expect(snack.bottom, lessThanOrEqualTo(nav.top));
    });

    testWidgets(
        'with extendBody, a tab using SafeArea(bottom: false) gets the full '
        'bar height as bottomInset', (tester) async {
      late double inset;
      await tester.pumpWidget(
        _host(
          body: SafeArea(
            bottom: false,
            child: Builder(
              builder: (context) {
                inset = AppSpacing.bottomInset(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final barHeight = tester.getSize(find.byType(PixelBottomNav)).height;
      expect(inset, barHeight + AppSpacing.s16);
    });

    testWidgets('a plain SafeArea would swallow the bar height', (tester) async {
      late double inset;
      await tester.pumpWidget(
        _host(
          body: SafeArea(
            child: Builder(
              builder: (context) {
                inset = AppSpacing.bottomInset(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      // This is why every tab screen must use SafeArea(bottom: false).
      expect(inset, AppSpacing.s16);
    });
  });
}
