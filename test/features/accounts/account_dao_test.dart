import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/accounts/data/datasources/account_dao.dart';

void main() {
  late AppDatabase db;
  late AccountDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = AccountDao(db);
  });
  tearDown(() => db.close());

  Future<int> addTx(
    String type,
    double amount, {
    int? accountId,
    int? toAccountId,
    int? linkedTransactionId,
  }) =>
      db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              transactionDate: '2026-07-01',
              transactionType: type,
              amount: amount,
              accountId: Value(accountId),
              toAccountId: Value(toAccountId),
              linkedTransactionId: Value(linkedTransactionId),
            ),
          );

  test('create, update, archive and delete', () async {
    final bca = await dao.create(
      name: 'BCA',
      color: '#111111',
      openingBalance: 100000,
    );
    expect(bca.id, greaterThan(0));

    await dao.update(
      id: bca.id,
      name: 'BCA Utama',
      color: '#222222',
      openingBalance: 150000,
    );
    await dao.setArchived(bca.id, archived: true);

    final stored = await dao.getById(bca.id);
    expect(stored!.name, 'BCA Utama');
    expect(stored.color, '#222222');
    expect(stored.openingBalance, 150000);
    expect(stored.isArchived, isTrue);

    await dao.delete(bca.id);
    expect(await dao.getAll(), isEmpty);
  });

  test('getAll keeps creation order', () async {
    await dao.create(name: 'BCA', openingBalance: 0);
    await dao.create(name: 'Dana', openingBalance: 0);
    expect((await dao.getAll()).map((a) => a.name), ['BCA', 'Dana']);
  });

  test('balance applies income, expense, admin fee, transfers and adjustments',
      () async {
    final bca = await dao.create(name: 'BCA', openingBalance: 100000);
    final dana = await dao.create(name: 'Dana', openingBalance: 0);
    await addTx('income', 50000, accountId: bca.id);
    await addTx('expense', 20000, accountId: bca.id);
    final transfer = await addTx(
      'transfer',
      30000,
      accountId: bca.id,
      toAccountId: dana.id,
    );
    await addTx(
      'expense',
      2500,
      accountId: bca.id,
      linkedTransactionId: transfer,
    );
    await addTx('adjustment', -5000, accountId: bca.id);
    await addTx('adjustment', 1000, accountId: dana.id);
    await addTx('expense', 99999);

    final balances = await dao.getBalances();
    expect(balances.map((b) => b.account.name), ['BCA', 'Dana']);
    expect(balances[0].balance, 92500);
    expect(balances[1].balance, 31000);
  });

  test('an account without transactions has its opening balance', () async {
    await dao.create(name: 'Cash', openingBalance: 85000);
    expect((await dao.getBalances()).single.balance, 85000);
  });

  test('hasTransactions sees the account as source or destination', () async {
    final bca = await dao.create(name: 'BCA', openingBalance: 0);
    final dana = await dao.create(name: 'Dana', openingBalance: 0);
    final cash = await dao.create(name: 'Cash', openingBalance: 0);
    await addTx('transfer', 1000, accountId: bca.id, toAccountId: dana.id);

    expect(await dao.hasTransactions(bca.id), isTrue);
    expect(await dao.hasTransactions(dana.id), isTrue);
    expect(await dao.hasTransactions(cash.id), isFalse);
  });

  group('lastUsedAccountId', () {
    test('is null when there are no accounts', () async {
      expect(await dao.lastUsedAccountId(transfer: false), isNull);
    });

    test('falls back to the first active account', () async {
      final bca = await dao.create(name: 'BCA', openingBalance: 0);
      await dao.setArchived(bca.id, archived: true);
      final dana = await dao.create(name: 'Dana', openingBalance: 0);
      expect(await dao.lastUsedAccountId(transfer: false), dana.id);
    });

    test('follows the newest income or expense, ignoring fees and transfers',
        () async {
      final bca = await dao.create(name: 'BCA', openingBalance: 0);
      final gopay = await dao.create(name: 'GoPay', openingBalance: 0);
      await addTx('expense', 10000, accountId: gopay.id);
      final t = await addTx(
        'transfer',
        5000,
        accountId: bca.id,
        toAccountId: gopay.id,
      );
      await addTx('expense', 2500, accountId: bca.id, linkedTransactionId: t);

      expect(await dao.lastUsedAccountId(transfer: false), gopay.id);
      expect(await dao.lastUsedAccountId(transfer: true), bca.id);
    });

    test('skips an archived account', () async {
      final bca = await dao.create(name: 'BCA', openingBalance: 0);
      final gopay = await dao.create(name: 'GoPay', openingBalance: 0);
      await addTx('expense', 10000, accountId: bca.id);
      await addTx('expense', 10000, accountId: gopay.id);
      await dao.setArchived(gopay.id, archived: true);

      expect(await dao.lastUsedAccountId(transfer: false), bca.id);
    });
  });

  test('createAdjustment stores a signed adjustment row', () async {
    final cash = await dao.create(name: 'Cash', openingBalance: 85000);
    await dao.createAdjustment(
      accountId: cash.id,
      amount: -25000,
      date: '2026-10-07',
    );

    final row = await db.select(db.transactions).getSingle();
    expect(row.transactionType, 'adjustment');
    expect(row.amount, -25000);
    expect(row.accountId, cash.id);
    expect(row.categoryId, isNull);
    expect(row.transactionDate, '2026-10-07');
    expect((await dao.getBalances()).single.balance, 60000);
  });
}
