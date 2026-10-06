import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/features/categories/domain/models/category_model.dart';
import 'package:pixel_pocket/features/categories/presentation/states/category_state.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/widgets/transaction_form_sheet.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';

/// Skips the real paginated load (and the database) — the form only reads
/// the controller's loading flag.
class _IdleTransactionsController extends TransactionsController {
  @override
  Future<List<TransactionModel>> build() async => const [];
}

Widget _host(TransactionFormSheet sheet) => ProviderScope(
      overrides: [
        categoriesProvider.overrideWith((ref) async => const <CategoryModel>[]),
        transactionsControllerProvider
            .overrideWith(_IdleTransactionsController.new),
        // Transactions tab parked on March 2025: for any real "today" after
        // it, the range-based default entry date is the month's last day.
        rangeFilterProvider.overrideWith(
          (ref) => RangeFilter(unit: RangeUnit.month, anchor: DateTime(2025, 3, 1)),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: sheet)),
    );

void main() {
  testWidgets('initialDate wins over the range-based default', (tester) async {
    await tester.pumpWidget(
      _host(TransactionFormSheet(initialDate: DateTime(2026, 1, 15))),
    );
    await tester.pump();
    expect(find.text('2026-01-15'), findsOneWidget);
  });

  testWidgets('without initialDate the date follows the Transactions range',
      (tester) async {
    await tester.pumpWidget(_host(const TransactionFormSheet()));
    await tester.pump();
    expect(find.text('2025-03-31'), findsOneWidget);
  });
}
