import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/features/accounts/application/services/account_service.dart';
import 'package:pixel_pocket/features/accounts/data/datasources/account_dao.dart';
import 'package:pixel_pocket/features/accounts/data/repositories/account_repository.dart';

void main() {
  late AppDatabase db;
  late AccountService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AccountService(AccountRepository(AccountDao(db)));
  });
  tearDown(() => db.close());

  Matcher failure(String message) =>
      throwsA(isA<Failure>().having((f) => f.message, 'message', message));

  test('create trims the name', () async {
    final a = await service.create(name: '  BCA  ', openingBalance: 100000);
    expect(a.name, 'BCA');
    expect((await service.list()).single.openingBalance, 100000);
  });

  test('create rejects an empty name', () {
    expect(service.create(name: '   '), failure('Enter an account name.'));
  });

  test('create rejects a duplicate name regardless of case', () async {
    await service.create(name: 'BCA');
    expect(
      service.create(name: 'bca'),
      failure('An account named "bca" already exists.'),
    );
  });

  test('update may keep the account\'s own name', () async {
    final a = await service.create(name: 'BCA');
    await service.update(
      id: a.id,
      name: 'BCA',
      color: '#111111',
      openingBalance: 5,
    );
    expect((await service.list()).single.color, '#111111');
  });

  test('update rejects another account\'s name', () async {
    await service.create(name: 'BCA');
    final dana = await service.create(name: 'Dana');
    expect(
      service.update(id: dana.id, name: 'BCA', openingBalance: 0),
      failure('An account named "BCA" already exists.'),
    );
  });

  test('remove deletes an account without transactions', () async {
    final a = await service.create(name: 'Cash');
    expect(await service.remove(a.id), AccountRemoval.deleted);
    expect(await service.list(), isEmpty);
  });

  test('remove archives an account with transactions', () async {
    final a = await service.create(name: 'Cash');
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 1000,
            accountId: Value(a.id),
          ),
        );
    expect(await service.remove(a.id), AccountRemoval.archived);
    expect((await service.list()).single.isArchived, isTrue);
  });

  test('unarchive brings an archived account back', () async {
    final a = await service.create(name: 'Cash');
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 1000,
            accountId: Value(a.id),
          ),
        );
    await service.remove(a.id);
    await service.unarchive(a.id);
    expect((await service.list()).single.isArchived, isFalse);
  });

  group('adjustBalance', () {
    test('records a negative difference', () async {
      final cash = await service.create(name: 'Cash', openingBalance: 85000);
      final created = await service.adjustBalance(
        accountId: cash.id,
        actualBalance: 60000,
        today: DateTime(2026, 10, 7),
      );
      expect(created, isTrue);
      final row = await db.select(db.transactions).getSingle();
      expect(row.transactionType, 'adjustment');
      expect(row.amount, -25000);
      expect(row.transactionDate, '2026-10-07');
      expect((await service.balances()).single.balance, 60000);
    });

    test('records a positive difference', () async {
      final jago = await service.create(name: 'Jago', openingBalance: 100000);
      await service.adjustBalance(accountId: jago.id, actualBalance: 100500);
      expect((await db.select(db.transactions).getSingle()).amount, 500);
    });

    test('does nothing when the balance already matches', () async {
      final cash = await service.create(name: 'Cash', openingBalance: 85000);
      final created = await service.adjustBalance(
        accountId: cash.id,
        actualBalance: 85000,
      );
      expect(created, isFalse);
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('throws for an unknown account', () {
      expect(
        service.adjustBalance(accountId: 42, actualBalance: 1),
        failure('Account not found.'),
      );
    });
  });

  group('moved', () {
    test('moves an account down to its new position', () {
      expect(AccountService.moved([1, 2, 3], 0, 2), [2, 3, 1]);
    });

    test('moves an account up to its new position', () {
      expect(AccountService.moved([1, 2, 3], 2, 0), [3, 1, 2]);
    });
  });
}
