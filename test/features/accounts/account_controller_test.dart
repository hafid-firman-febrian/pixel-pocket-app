import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/cache/cache_store.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/accounts/presentation/controllers/account_controller.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('creating an account refreshes the balances', () async {
    expect(await container.read(accountBalancesProvider.future), isEmpty);

    await container
        .read(accountControllerProvider)
        .create(name: 'Cash', openingBalance: 85000);

    final balances = await container.read(accountBalancesProvider.future);
    expect(balances.single.balance, 85000);
  });

  test('adjusting a balance bumps the transactions revision', () async {
    await container
        .read(accountControllerProvider)
        .create(name: 'Cash', openingBalance: 85000);
    final cash = (await container.read(accountsProvider.future)).single;
    final before = container.read(transactionsRevisionProvider);

    final created = await container
        .read(accountControllerProvider)
        .adjustBalance(accountId: cash.id, actualBalance: 60000);

    expect(created, isTrue);
    expect(container.read(transactionsRevisionProvider), greaterThan(before));
    final balances = await container.read(accountBalancesProvider.future);
    expect(balances.single.balance, 60000);
  });

  test('activeAccountsProvider hides archived accounts', () async {
    final controller = container.read(accountControllerProvider);
    await controller.create(name: 'BCA', openingBalance: 0);
    await controller.create(name: 'Old', openingBalance: 0);
    final old = (await container.read(accountsProvider.future)).last;
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 1,
            accountId: Value(old.id),
          ),
        );
    await controller.remove(old.id);

    final active = await container.read(activeAccountsProvider.future);
    expect(active.map((a) => a.name), ['BCA']);
  });

  test('moving an account refreshes the order', () async {
    final controller = container.read(accountControllerProvider);
    await controller.create(name: 'BCA', openingBalance: 0);
    await controller.create(name: 'Dana', openingBalance: 0);
    await controller.create(name: 'Cash', openingBalance: 0);
    final ids =
        (await container.read(accountsProvider.future)).map((a) => a.id).toList();

    await controller.move(ids: ids, from: 2, to: 0);

    final names =
        (await container.read(accountsProvider.future)).map((a) => a.name);
    expect(names, ['Cash', 'BCA', 'Dana']);
  });
}
