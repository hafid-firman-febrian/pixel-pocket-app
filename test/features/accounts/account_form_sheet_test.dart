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
    await tester.enterText(find.byType(TextFormField).at(0), 'Cash');
    await tester.enterText(find.byType(TextFormField).at(1), '85000');
    await save(tester);
    expect(controller.created, [('Cash', pixelColorPalette.first, 85000.0)]);
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
}
