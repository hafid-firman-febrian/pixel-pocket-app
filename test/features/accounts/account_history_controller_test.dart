import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/accounts/presentation/controllers/account_history_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(id: const Value(1), name: 'BCA'),
        );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(id: const Value(2), name: 'Dana'),
        );
    for (var i = 0; i < 24; i++) {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              transactionDate: '2026-07-01',
              transactionType: 'expense',
              amount: 1000,
              accountId: const Value(1),
            ),
          );
    }
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: '2026-07-02',
            transactionType: 'transfer',
            amount: 5000,
            accountId: const Value(2),
            toAccountId: const Value(1),
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('loads pages of the account history, including transfers in',
      () async {
    final provider = accountHistoryControllerProvider(1);
    container.listen(provider, (_, _) {});

    final first = await container.read(provider.future);
    expect(first.length, 20);
    expect(first.first.transactionType, 'transfer');
    expect(container.read(provider.notifier).hasMore, isTrue);

    await container.read(provider.notifier).loadMore();
    expect(container.read(provider).valueOrNull!.length, 25);
    expect(container.read(provider.notifier).hasMore, isFalse);
  });
}
