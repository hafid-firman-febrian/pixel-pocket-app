import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_pocket/core/router/app_router.dart';
import 'package:pixel_pocket/features/auth/presentation/controllers/pin_controller.dart';
import 'package:pixel_pocket/features/auth/presentation/screens/set_pin_screen.dart';
import 'package:pixel_pocket/features/auth/presentation/screens/unlock_pin_screen.dart';

class _FakePinController extends PinController {
  _FakePinController({this.correctPin = '0000'});

  final String correctPin;
  final verified = <String>[];
  final saved = <String>[];

  @override
  bool? build() => true;

  @override
  Future<bool> verifyPin(String pin) async {
    verified.add(pin);
    return pin == correctPin;
  }

  @override
  Future<void> setPin(String pin) async {
    saved.add(pin);
  }
}

Widget _host(Widget screen, PinController controller) => ProviderScope(
  overrides: [pinControllerProvider.overrideWith(() => controller)],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen),
        GoRoute(
          path: AppRoutes.resetPin,
          builder: (context, state) => const Text('reset-pin route'),
        ),
      ],
    ),
  ),
);

Future<void> _enter(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _failAttempts(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await _enter(tester, '1111');
  }
}

final _filledSlot = find.text('■');
final _forgotPin = find.text('> [ FORGOT PIN? ]');

void main() {
  group('UnlockPinScreen', () {
    testWidgets('keypad digits are verified in order and unlock on a match', (
      tester,
    ) async {
      final pins = _FakePinController(correctPin: '1290');
      var unlocked = false;
      await tester.pumpWidget(
        _host(UnlockPinScreen(onSuccess: () => unlocked = true), pins),
      );

      await _enter(tester, '1290');

      expect(pins.verified, ['1290']);
      expect(unlocked, isTrue);
    });

    testWidgets('DEL removes the last digit before verification', (
      tester,
    ) async {
      final pins = _FakePinController();
      await tester.pumpWidget(_host(const UnlockPinScreen(), pins));

      await _enter(tester, '12');
      await tester.tap(find.text('DEL'));
      await tester.pump();
      await _enter(tester, '345');

      expect(pins.verified, ['1345']);
    });

    testWidgets('each typed digit fills one ■ slot', (tester) async {
      await tester.pumpWidget(
        _host(const UnlockPinScreen(), _FakePinController()),
      );

      await _enter(tester, '12');

      expect(_filledSlot, findsNWidgets(2));
    });

    testWidgets('a wrong PIN reports ACCESS DENIED with the attempts left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const UnlockPinScreen(), _FakePinController()),
      );

      await _failAttempts(tester, 1);

      expect(find.text('> ACCESS DENIED'), findsOneWidget);
      expect(find.text('> 5 ATTEMPTS LEFT'), findsOneWidget);
      expect(_filledSlot, findsNothing);
    });

    testWidgets('the last attempt is announced in singular', (tester) async {
      await tester.pumpWidget(
        _host(const UnlockPinScreen(), _FakePinController()),
      );

      await _failAttempts(tester, 5);

      expect(find.text('> 1 ATTEMPT LEFT'), findsOneWidget);
    });

    testWidgets('six wrong PINs lock the keypad behind a countdown', (
      tester,
    ) async {
      final pins = _FakePinController();
      await tester.pumpWidget(_host(const UnlockPinScreen(), pins));

      await _failAttempts(tester, 6);
      expect(find.text('> SYSTEM LOCKED: 30s'), findsOneWidget);

      await tester.tap(find.text('1'), warnIfMissed: false);
      await tester.pump();
      expect(_filledSlot, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('> SYSTEM LOCKED: 29s'), findsOneWidget);
    });

    testWidgets('the lock lifts after 30 seconds', (tester) async {
      await tester.pumpWidget(
        _host(const UnlockPinScreen(), _FakePinController()),
      );

      await _failAttempts(tester, 6);
      await tester.pump(const Duration(seconds: 30));

      expect(find.text('> ENTER 4-DIGIT PIN'), findsOneWidget);
      expect(find.text('> ACCESS DENIED'), findsNothing);
      await _enter(tester, '1');
      expect(_filledSlot, findsOneWidget);
    });

    testWidgets('Forgot PIN is offered only while locked and opens reset', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const UnlockPinScreen(), _FakePinController()),
      );
      expect(_forgotPin, findsNothing);

      await _failAttempts(tester, 6);
      await tester.tap(_forgotPin);
      await tester.pumpAndSettle();

      expect(find.text('reset-pin route'), findsOneWidget);
    });
  });

  group('SetPinScreen', () {
    testWidgets('the first four digits move on to the confirm step', (
      tester,
    ) async {
      final pins = _FakePinController();
      await tester.pumpWidget(_host(const SetPinScreen(), pins));
      expect(find.text('> CREATE 4-DIGIT PIN'), findsOneWidget);

      await _enter(tester, '1234');

      expect(find.text('> CREATE 4-DIGIT PIN ✓'), findsOneWidget);
      expect(find.text('> RE-ENTER PIN TO CONFIRM'), findsOneWidget);
      expect(pins.saved, isEmpty);
    });

    testWidgets('a mismatched confirmation starts over', (tester) async {
      final pins = _FakePinController();
      await tester.pumpWidget(_host(const SetPinScreen(), pins));

      await _enter(tester, '1234');
      await _enter(tester, '5678');

      expect(find.text('> PIN MISMATCH. START OVER'), findsOneWidget);
      expect(find.text('> CREATE 4-DIGIT PIN'), findsOneWidget);
      expect(find.text('> RE-ENTER PIN TO CONFIRM'), findsNothing);
      expect(pins.saved, isEmpty);

      await _enter(tester, '1');
      expect(find.text('> PIN MISMATCH. START OVER'), findsNothing);
    });

    testWidgets('a matching confirmation saves the PIN and completes', (
      tester,
    ) async {
      final pins = _FakePinController();
      var completed = false;
      await tester.pumpWidget(
        _host(SetPinScreen(onComplete: () => completed = true), pins),
      );

      await _enter(tester, '1234');
      await _enter(tester, '1234');

      expect(pins.saved, ['1234']);
      expect(completed, isTrue);
    });
  });
}
