import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/widgets/pixel_color_picker.dart';
import 'package:pixel_pocket/features/accounts/presentation/controllers/account_controller.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/account_form_sheet.dart';

class _RecordingController extends AccountController {
  _RecordingController(super.ref, {this.error});

  final Failure? error;
  final created = <(String, String?, double)>[];

  @override
  Future<void> create({
    required String name,
    String? color,
    required double openingBalance,
  }) async {
    if (error != null) throw error!;
    created.add((name, color, openingBalance));
  }
}

void main() {
  late _RecordingController controller;

  Future<void> open(WidgetTester tester, {Failure? error}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountControllerProvider.overrideWith((ref) {
            controller = _RecordingController(ref, error: error);
            return controller;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AccountFormSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('SAVE ACCOUNT'));
    await tester.tap(find.text('SAVE ACCOUNT'));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty name is rejected', (tester) async {
    await open(tester);
    await save(tester);
    expect(find.text('Enter a name'), findsOneWidget);
  });

  testWidgets('saving sends the name, color and opening balance',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Dompet');
    await tester.enterText(find.byType(TextFormField).at(1), '85000');
    await save(tester);
    expect(controller.created, [('Dompet', pixelColorPalette.first, 85000.0)]);
    expect(find.text('NEW ACCOUNT'), findsNothing);
  });

  testWidgets('a service error is shown', (tester) async {
    await open(
      tester,
      error: const Failure(message: 'An account named "Cash" already exists.'),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Cash');
    await save(tester);
    expect(find.text('An account named "Cash" already exists.'), findsOneWidget);
  });

  testWidgets('typing a brand name picks its color', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Dana');
    await save(tester);
    expect(controller.created.single.$2, '#4791C2');
  });

  testWidgets('a color picked by hand is kept when the name changes',
      (tester) async {
    await open(tester);
    final swatch = find.byKey(ValueKey(pixelColorPalette[3]));
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dana');
    await save(tester);
    expect(controller.created.single.$2, pixelColorPalette[3]);
  });

  testWidgets('brand colors come first in the picker', (tester) async {
    await open(tester);
    final picker = tester.widget<PixelColorPicker>(find.byType(PixelColorPicker));
    expect(picker.palette.take(5), [
      '#386694',
      '#4791C2',
      '#46A6B9',
      '#D8A246',
      '#46915F',
    ]);
    expect(picker.palette.skip(5), pixelColorPalette);
  });
}
