import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/features/transactions/application/services/transaction_service.dart';
import 'package:pixel_pocket/features/transactions/data/datasources/transaction_dao.dart';
import 'package:pixel_pocket/features/transactions/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionService(TransactionRepository(TransactionDao(db)));
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(id: const Value(1), name: 'BCA'),
        );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(id: const Value(2), name: 'Dana'),
        );
  });
  tearDown(() => db.close());

  Matcher failure(String message) =>
      throwsA(isA<Failure>().having((f) => f.message, 'message', message));

  Future<void> transfer({
    double amount = 50000,
    int? from = 1,
    int? to = 2,
    double fee = 0,
  }) =>
      service.createTransfer(
        transactionDate: '2026-07-01',
        amount: amount,
        fromAccountId: from,
        toAccountId: to,
        fee: fee,
      );

  test('rejects a missing source account', () {
    expect(transfer(from: null), failure('Select the account to transfer from.'));
  });

  test('rejects a missing destination account', () {
    expect(transfer(to: null), failure('Select the account to transfer to.'));
  });

  test('rejects the same account on both sides', () {
    expect(transfer(to: 1), failure('Choose two different accounts.'));
  });

  test('rejects a non-positive amount', () {
    expect(transfer(amount: 0), failure('Enter a valid amount.'));
  });

  test('rejects a negative fee', () {
    expect(transfer(fee: -1), failure('Admin fee cannot be negative.'));
  });

  test('saves the transfer with its fee', () async {
    await transfer(fee: 2500);
    final rows = await db.select(db.transactions).get();
    expect(rows.map((r) => r.transactionType), ['transfer', 'expense']);
  });

  test('updateTransfer validates like createTransfer', () async {
    await transfer();
    final id = (await db.select(db.transactions).getSingle()).id;
    expect(
      service.updateTransfer(
        id: id,
        transactionDate: '2026-07-01',
        amount: 1,
        fromAccountId: 2,
        toAccountId: 2,
      ),
      failure('Choose two different accounts.'),
    );
  });

  test('create keeps the account', () async {
    final created = await service.create(
      transactionDate: '2026-07-01',
      transactionType: 'expense',
      amount: 1000,
      accountId: 2,
    );
    expect(created.accountName, 'Dana');
  });
}
