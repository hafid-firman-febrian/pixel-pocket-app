import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/cache/cache_store.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/chart/presentation/states/chart_state.dart';
import 'package:pixel_pocket/features/dashboard/presentation/states/dashboard_state.dart';
import 'package:pixel_pocket/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The navbar's + button saves from Home and Chart too, so the read models
/// those tabs show must refetch after a save — not only the Transactions list.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    // The controller is auto-dispose; keep it alive like an open screen would.
    container.listen(transactionsControllerProvider, (_, _) {});
    await container.read(transactionsControllerProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<bool> saveExpenseToday() => container
      .read(transactionsControllerProvider.notifier)
      .create(
        transactionDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        transactionType: 'expense',
        amount: 25000,
      );

  test('saving a transaction refreshes the dashboard summary', () async {
    final before = await container.read(dashboardSummaryProvider.future);
    expect(before.transactionCount, 0);

    expect(await saveExpenseToday(), isTrue);

    final after = await container.read(dashboardSummaryProvider.future);
    expect(after.transactionCount, 1);
    expect(after.totalExpense, 25000);
  });

  test('saving a transaction refreshes the dashboard recent list', () async {
    expect(await container.read(recentTransactionsProvider.future), isEmpty);

    expect(await saveExpenseToday(), isTrue);

    expect(await container.read(recentTransactionsProvider.future), hasLength(1));
  });

  test('saving a transaction refreshes the chart', () async {
    double expenseTotal(List<double> values) =>
        values.fold(0.0, (sum, v) => sum + v);

    final before = await container.read(chartProvider.future);
    expect(expenseTotal(before.expense), 0);

    expect(await saveExpenseToday(), isTrue);

    final after = await container.read(chartProvider.future);
    expect(expenseTotal(after.expense), 25000);
  });
}
