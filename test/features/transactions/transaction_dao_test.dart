import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/features/transactions/data/datasources/transaction_dao.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_filter.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

void main() {
  late AppDatabase db;
  late TransactionDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = TransactionDao(db);
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: const Value(1), name: 'Food', color: const Value('#abcdef'), type: 'expense',
      ),
    );
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(id: const Value(1), name: 'BCA'),
    );
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(id: const Value(2), name: 'Dana'),
    );
  });
  tearDown(() => db.close());

  TransactionModel tx({
    String date = '2026-07-01',
    String type = 'expense',
    double amount = 10,
    int? categoryId = 1,
  }) => TransactionModel(
        id: 0, transactionDate: date, transactionType: type,
        amount: amount, categoryId: categoryId,
      );

  test('create returns row with id and getAll joins category name/color', () async {
    final created = await dao.create(tx());
    expect(created.id, greaterThan(0));
    final all = await dao.getAll(const TransactionFilter(limit: 20));
    expect(all.length, 1);
    expect(all.first.categoryName, 'Food');
    expect(all.first.categoryColor, '#abcdef');
  });

  test('filters by transaction_type', () async {
    await dao.create(tx(type: 'expense'));
    await dao.create(tx(type: 'income', categoryId: null));
    final expenses = await dao.getAll(const TransactionFilter(transactionType: 'expense', limit: 20));
    expect(expenses.length, 1);
    expect(expenses.first.transactionType, 'expense');
  });

  test('filters by custom date range', () async {
    await dao.create(tx(date: '2026-07-01'));
    await dao.create(tx(date: '2026-07-20'));
    final inRange = await dao.getAll(const TransactionFilter(
      filter: 'custom', startDate: '2026-07-10', endDate: '2026-07-31', limit: 20,
    ));
    expect(inRange.length, 1);
    expect(inRange.first.transactionDate, '2026-07-20');
  });

  test('paginates by page/limit', () async {
    for (var i = 1; i <= 5; i++) {
      await dao.create(tx(date: '2026-07-0$i'));
    }
    final page1 = await dao.getAll(const TransactionFilter(page: 1, limit: 2));
    final page2 = await dao.getAll(const TransactionFilter(page: 2, limit: 2));
    expect(page1.length, 2);
    expect(page2.length, 2);
    expect(page1.map((t) => t.id).toSet().intersection(page2.map((t) => t.id).toSet()), isEmpty);
  });

  test('salary period filter overrides date and uses period bounds', () async {
    await db.into(db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
      id: const Value(9), name: 'Jul', startDate: '2026-07-01', endDate: '2026-07-15',
    ));
    await dao.create(tx(date: '2026-07-05'));
    await dao.create(tx(date: '2026-07-25'));
    final inPeriod = await dao.getAll(const TransactionFilter(salaryPeriodId: 9, limit: 20));
    expect(inPeriod.length, 1);
    expect(inPeriod.first.transactionDate, '2026-07-05');
  });

  test('update with unknown id throws Failure notFound', () async {
    await expectLater(
      dao.update(const TransactionModel(
        id: 999, transactionDate: '2026-07-01', transactionType: 'expense',
        amount: 10, categoryId: 1,
      )),
      throwsA(isA<Failure>().having((f) => f.type, 'type', FailureType.notFound)),
    );
  });

  test('update and delete', () async {
    final c = await dao.create(tx(amount: 10));
    final u = await dao.update(TransactionModel(
      id: c.id, transactionDate: c.transactionDate, transactionType: 'expense',
      amount: 99, categoryId: 1,
    ));
    expect(u.amount, 99);
    await dao.delete(c.id);
    expect(await dao.getAll(const TransactionFilter(limit: 20)), isEmpty);
  });

  group('accounts and transfers', () {
    TransactionModel transfer({
      int id = 0,
      double amount = 50000,
      int from = 1,
      int to = 2,
      String date = '2026-07-01',
    }) =>
        TransactionModel(
          id: id,
          transactionDate: date,
          transactionType: 'transfer',
          amount: amount,
          accountId: from,
          toAccountId: to,
        );

    Future<List<Transaction>> rows() => db.select(db.transactions).get();

    test('create stores the account and getAll joins its name', () async {
      await dao.create(const TransactionModel(
        id: 0, transactionDate: '2026-07-01', transactionType: 'expense',
        amount: 10, categoryId: 1, accountId: 2,
      ));
      final t = (await dao.getAll(const TransactionFilter())).single;
      expect(t.accountId, 2);
      expect(t.accountName, 'Dana');
    });

    test('update can change the account', () async {
      final c = await dao.create(const TransactionModel(
        id: 0, transactionDate: '2026-07-01', transactionType: 'expense',
        amount: 10, categoryId: 1, accountId: 1,
      ));
      final u = await dao.update(TransactionModel(
        id: c.id, transactionDate: c.transactionDate, transactionType: 'expense',
        amount: 10, categoryId: 1, accountId: 2,
      ));
      expect(u.accountName, 'Dana');
    });

    test('createTransfer with a fee writes a linked Admin Fee expense', () async {
      final created = await dao.createTransfer(transfer(), fee: 2500);
      expect(created.isTransfer, isTrue);
      expect(created.accountName, 'BCA');
      expect(created.toAccountName, 'Dana');
      expect(created.feeAmount, 2500);

      final fee = (await rows()).singleWhere((r) => r.linkedTransactionId == created.id);
      expect(fee.transactionType, 'expense');
      expect(fee.amount, 2500);
      expect(fee.accountId, 1);
      expect(fee.categoryId, await db.adminFeeCategoryId());
    });

    test('createTransfer without a fee writes only the transfer', () async {
      final created = await dao.createTransfer(transfer());
      expect(created.feeAmount, isNull);
      expect((await rows()).length, 1);
    });

    test('createTransfer rolls back the transfer when the fee cannot be written', () async {
      await db.customStatement('DROP TABLE categories');
      await expectLater(dao.createTransfer(transfer(), fee: 2500), throwsA(anything));
      expect(await rows(), isEmpty);
    });

    test('updateTransfer adds, changes and removes the fee', () async {
      final created = await dao.createTransfer(transfer());

      var updated = await dao.updateTransfer(transfer(id: created.id), fee: 2500);
      expect(updated.feeAmount, 2500);

      updated = await dao.updateTransfer(
        transfer(id: created.id, amount: 70000, from: 2, to: 1, date: '2026-07-09'),
        fee: 1000,
      );
      expect(updated.amount, 70000);
      expect(updated.accountName, 'Dana');
      expect(updated.feeAmount, 1000);
      final fee = (await rows()).singleWhere((r) => r.linkedTransactionId == created.id);
      expect(fee.accountId, 2);
      expect(fee.transactionDate, '2026-07-09');

      updated = await dao.updateTransfer(transfer(id: created.id), fee: 0);
      expect(updated.feeAmount, isNull);
      expect((await rows()).length, 1);
    });

    test('deleting a transfer deletes its fee', () async {
      final created = await dao.createTransfer(transfer(), fee: 2500);
      await dao.delete(created.id);
      expect(await rows(), isEmpty);
    });

    test('accountId filter matches the source and the destination', () async {
      await dao.create(const TransactionModel(
        id: 0, transactionDate: '2026-07-01', transactionType: 'expense',
        amount: 10, categoryId: 1, accountId: 1,
      ));
      await dao.createTransfer(transfer(), fee: 2500);

      final bca = await dao.getAll(const TransactionFilter(accountId: 1));
      final dana = await dao.getAll(const TransactionFilter(accountId: 2));
      expect(bca.length, 3);
      expect(dana.map((t) => t.transactionType), ['transfer']);
    });

    test('getById returns the joined row', () async {
      final created = await dao.createTransfer(transfer(), fee: 2500);
      final loaded = await dao.getById(created.id);
      expect(loaded.toAccountName, 'Dana');
      expect(loaded.feeAmount, 2500);
    });
  });
}
