import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_filter.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

class TransactionDao {
  TransactionDao(this._db);

  final AppDatabase _db;

  late final $AccountsTable _fromAccount =
      _db.alias(_db.accounts, 'from_account');
  late final $AccountsTable _toAccount = _db.alias(_db.accounts, 'to_account');
  late final $TransactionsTable _fee = _db.alias(_db.transactions, 'fee');

  Future<List<TransactionModel>> getAll(TransactionFilter filter) async {
    final t = _db.transactions;
    final query = _joined();

    String? startDate = filter.startDate;
    String? endDate = filter.endDate;

    if (filter.salaryPeriodId != null) {
      final period = await (_db.select(_db.salaryPeriods)
            ..where((p) => p.id.equals(filter.salaryPeriodId!)))
          .getSingleOrNull();
      if (period != null) {
        startDate = period.startDate;
        endDate = period.endDate;
      }
    }

    if (startDate != null) {
      query.where(t.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(t.transactionDate.isSmallerOrEqualValue(endDate));
    }
    if (filter.transactionType != null) {
      query.where(t.transactionType.equals(filter.transactionType!));
    }
    if (filter.categoryId != null) {
      query.where(t.categoryId.equals(filter.categoryId!));
    }
    if (filter.accountId != null) {
      query.where(
        t.accountId.equals(filter.accountId!) |
            t.toAccountId.equals(filter.accountId!),
      );
    }

    query
      ..orderBy([
        OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
        OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(filter.limit, offset: (filter.page - 1) * filter.limit);

    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  Future<TransactionModel> getById(int id) => _byId(id);

  Future<TransactionModel> create(TransactionModel m) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: m.transactionDate,
            transactionType: m.transactionType,
            amount: m.amount,
            categoryId: Value(m.categoryId),
            description: Value(m.description),
            accountId: Value(m.accountId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return _byId(id);
  }

  Future<TransactionModel> update(TransactionModel m) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(m.id))).write(
      TransactionsCompanion(
        transactionDate: Value(m.transactionDate),
        transactionType: Value(m.transactionType),
        amount: Value(m.amount),
        categoryId: Value(m.categoryId),
        description: Value(m.description),
        accountId: Value(m.accountId),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
    return _byId(m.id);
  }

  Future<TransactionModel> createTransfer(
    TransactionModel transfer, {
    double fee = 0,
  }) async {
    final id = await _db.transaction(() async {
      final now = DateTime.now().toIso8601String();
      final id = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              transactionDate: transfer.transactionDate,
              transactionType: 'transfer',
              amount: transfer.amount,
              accountId: Value(transfer.accountId),
              toAccountId: Value(transfer.toAccountId),
              description: Value(transfer.description),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      if (fee > 0) {
        await _insertFee(transferId: id, transfer: transfer, fee: fee, now: now);
      }
      return id;
    });
    return _byId(id);
  }

  Future<TransactionModel> updateTransfer(
    TransactionModel transfer, {
    double fee = 0,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now().toIso8601String();
      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(transfer.id)))
          .write(
        TransactionsCompanion(
          transactionDate: Value(transfer.transactionDate),
          transactionType: const Value('transfer'),
          amount: Value(transfer.amount),
          categoryId: const Value(null),
          accountId: Value(transfer.accountId),
          toAccountId: Value(transfer.toAccountId),
          description: Value(transfer.description),
          updatedAt: Value(now),
        ),
      );
      final existingFee = await (_db.select(_db.transactions)
            ..where((t) => t.linkedTransactionId.equals(transfer.id)))
          .getSingleOrNull();
      if (fee <= 0) {
        if (existingFee != null) {
          await (_db.delete(_db.transactions)
                ..where((t) => t.id.equals(existingFee.id)))
              .go();
        }
        return;
      }
      if (existingFee == null) {
        await _insertFee(
          transferId: transfer.id,
          transfer: transfer,
          fee: fee,
          now: now,
        );
        return;
      }
      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(existingFee.id)))
          .write(
        TransactionsCompanion(
          transactionDate: Value(transfer.transactionDate),
          amount: Value(fee),
          accountId: Value(transfer.accountId),
          updatedAt: Value(now),
        ),
      );
    });
    return _byId(transfer.id);
  }

  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.transactions)
            ..where((t) => t.linkedTransactionId.equals(id)))
          .go();
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> _insertFee({
    required int transferId,
    required TransactionModel transfer,
    required double fee,
    required String now,
  }) async {
    final categoryId = await _db.adminFeeCategoryId();
    await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: transfer.transactionDate,
            transactionType: 'expense',
            amount: fee,
            categoryId: Value(categoryId),
            accountId: Value(transfer.accountId),
            linkedTransactionId: Value(transferId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _joined() {
    final t = _db.transactions;
    final c = _db.categories;
    return _db.select(t).join([
      leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
      leftOuterJoin(_fromAccount, _fromAccount.id.equalsExp(t.accountId)),
      leftOuterJoin(_toAccount, _toAccount.id.equalsExp(t.toAccountId)),
      leftOuterJoin(_fee, _fee.linkedTransactionId.equalsExp(t.id)),
    ]);
  }

  Future<TransactionModel> _byId(int id) async {
    final row = await (_joined()..where(_db.transactions.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      throw const Failure(
        message: 'Transaction not found.',
        type: FailureType.notFound,
      );
    }
    return _toModel(row);
  }

  TransactionModel _toModel(TypedResult row) {
    final tx = row.readTable(_db.transactions);
    final cat = row.readTableOrNull(_db.categories);
    final from = row.readTableOrNull(_fromAccount);
    final to = row.readTableOrNull(_toAccount);
    final fee = row.readTableOrNull(_fee);
    return TransactionModel(
      id: tx.id,
      transactionDate: tx.transactionDate,
      transactionType: tx.transactionType,
      amount: tx.amount,
      categoryId: tx.categoryId,
      description: tx.description,
      categoryName: cat?.name,
      categoryColor: cat?.color,
      accountId: tx.accountId,
      accountName: from?.name,
      toAccountId: tx.toAccountId,
      toAccountName: to?.name,
      linkedTransactionId: tx.linkedTransactionId,
      feeAmount: fee?.amount,
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
    );
  }
}

final transactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(ref.watch(appDatabaseProvider)),
);
