import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/cache/cache_store.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
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

  test('saving a transfer leaves dashboard totals alone and moves balances',
      () async {
    final bca = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            name: 'BCA',
            openingBalance: const Value(100000),
          ),
        );
    final dana =
        await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Dana'));
    await container.read(accountBalancesProvider.future);

    final ok = await container
        .read(transactionsControllerProvider.notifier)
        .createTransfer(
          transactionDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          amount: 50000,
          fromAccountId: bca,
          toAccountId: dana,
          fee: 2500,
        );
    expect(ok, isTrue);

    final summary = await container.read(dashboardSummaryProvider.future);
    expect(summary.totalIncome, 0);
    expect(summary.totalExpense, 2500);
    expect(summary.transactionCount, 1);

    final balances = await container.read(accountBalancesProvider.future);
    expect(balances.map((b) => b.balance), [47500, 50000]);
  });

  group('deleting linked rows from the list', () {
    late int bca;
    late int dana;

    setUp(() async {
      bca = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'BCA'));
      dana = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Dana'));
      final ok = await container
          .read(transactionsControllerProvider.notifier)
          .createTransfer(
            transactionDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            amount: 50000,
            fromAccountId: bca,
            toAccountId: dana,
            fee: 2500,
          );
      expect(ok, isTrue);
      expect(container.read(transactionsControllerProvider).valueOrNull!.length, 2);
    });

    test('deleting a transfer also drops its admin fee from the list', () async {
      final transfer = container
          .read(transactionsControllerProvider)
          .valueOrNull!
          .firstWhere((t) => t.isTransfer);

      await container.read(transactionsControllerProvider.notifier).delete(transfer.id);

      expect(container.read(transactionsControllerProvider).valueOrNull, isEmpty);
    });

    test('deleting an admin fee clears it from its transfer in the list', () async {
      final fee = container
          .read(transactionsControllerProvider)
          .valueOrNull!
          .firstWhere((t) => t.isAdminFee);

      await container.read(transactionsControllerProvider.notifier).delete(fee.id);

      final rows = container.read(transactionsControllerProvider).valueOrNull!;
      expect(rows.single.isTransfer, isTrue);
      expect(rows.single.feeAmount, isNull);
    });
  });
}
