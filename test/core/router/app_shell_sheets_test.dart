import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_pocket/core/router/app_router.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_nav.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixel_pocket/features/categories/domain/models/category_model.dart';
import 'package:pixel_pocket/features/categories/presentation/states/category_state.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/widgets/transaction_form_sheet.dart';

/// Skips the real paginated load (and the database).
class _IdleTransactionsController extends TransactionsController {
  @override
  Future<List<TransactionModel>> build() async => const [];
}

const _tx = TransactionModel(
  id: 1,
  transactionDate: '2026-10-01',
  transactionType: 'expense',
  amount: 5000,
);

/// A tab screen shaped like the real ones (SafeArea(bottom: false) around a
/// nested Scaffold) that opens the edit sheet from its own context.
Widget _tab(String path) => SafeArea(
  bottom: false,
  child: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => TransactionFormSheet.show(context, existing: _tx),
          child: Text('edit $path'),
        ),
      ),
    ),
  ),
);

Widget _app() {
  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final path in [
            AppRoutes.dashboard,
            AppRoutes.transactions,
            AppRoutes.chart,
            AppRoutes.settings,
          ])
            StatefulShellBranch(
              routes: [GoRoute(path: path, builder: (_, _) => _tab(path))],
            ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      categoriesProvider.overrideWith((ref) async => const <CategoryModel>[]),
      transactionsControllerProvider.overrideWith(
        _IdleTransactionsController.new,
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// iPhone-sized view with a home indicator.
void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

Rect _barRect(WidgetTester tester) =>
    tester.getRect(find.byType(PixelBottomNav));

bool _hits(WidgetTester tester, Offset point, Finder target) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, point, tester.view.viewId);
  final renderObject = tester.renderObject(target);
  return result.path.any((entry) => entry.target == renderObject);
}

Finder get _addButton => find.descendant(
  of: find.byType(PixelBottomNav),
  matching: find.byType(PixelButton),
);

void main() {
  testWidgets('a sheet opened from a tab sits above the navbar',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('edit ${AppRoutes.dashboard}'));
    await tester.pumpAndSettle();

    final bar = _barRect(tester);
    final cancel = tester.getRect(find.text('CANCEL'));
    expect(cancel.bottom, lessThanOrEqualTo(bar.top));
    expect(_hits(tester, cancel.center, find.text('CANCEL')), isTrue);
    expect(_hits(tester, cancel.center, find.byType(PixelBottomNav)), isFalse);
  });

  testWidgets('a validation snackbar from the + sheet is shown above it',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(_addButton);
    await tester.pumpAndSettle();
    expect(find.text('NEW TRANSACTION'), findsOneWidget);

    // Amount but no category → the form answers with a snackbar.
    await tester.tap(find.text('+5K'));
    await tester.pump();
    await tester.ensureVisible(find.text('SAVE TRANSACTION'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE TRANSACTION'));
    await tester.pumpAndSettle();

    final message = find.text('Please select a category first');
    expect(message, findsOneWidget);
    expect(_hits(tester, tester.getCenter(message), message), isTrue);
  });
}
