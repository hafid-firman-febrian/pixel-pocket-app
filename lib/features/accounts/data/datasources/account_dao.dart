import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';

const _balanceSql = '''
SELECT a.id AS id,
  a.opening_balance
  + COALESCE((SELECT SUM(CASE t.transaction_type
        WHEN 'income' THEN t.amount
        WHEN 'adjustment' THEN t.amount
        WHEN 'expense' THEN -t.amount
        WHEN 'transfer' THEN -t.amount
        ELSE 0 END)
      FROM transactions t WHERE t.account_id = a.id), 0)
  + COALESCE((SELECT SUM(t.amount) FROM transactions t
      WHERE t.transaction_type = 'transfer' AND t.to_account_id = a.id), 0)
  AS balance
FROM accounts a
''';

class AccountDao {
  AccountDao(this._db);

  final AppDatabase _db;

  Future<List<AccountModel>> getAll() async {
    final rows = await (_db.select(_db.accounts)
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<AccountModel?> getById(int id) async {
    final row = await (_db.select(_db.accounts)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  Future<AccountModel> create({
    required String name,
    String? color,
    required double openingBalance,
  }) async {
    final id = await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            name: name,
            color: Value(color),
            openingBalance: Value(openingBalance),
          ),
        );
    return AccountModel(
      id: id,
      name: name,
      color: color,
      openingBalance: openingBalance,
    );
  }

  Future<void> update({
    required int id,
    required String name,
    String? color,
    required double openingBalance,
  }) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(name),
        color: Value(color),
        openingBalance: Value(openingBalance),
      ),
    );
  }

  Future<void> setArchived(int id, {required bool archived}) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(isArchived: Value(archived)));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  Future<bool> hasTransactions(int id) async {
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.accountId.equals(id) | t.toAccountId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<List<AccountBalance>> getBalances() async {
    final accounts = await getAll();
    final rows = await _db
        .customSelect(
          _balanceSql,
          readsFrom: {_db.accounts, _db.transactions},
        )
        .get();
    final byId = {
      for (final r in rows)
        r.read<int>('id'): (r.data['balance'] as num).toDouble(),
    };
    return [
      for (final a in accounts)
        AccountBalance(account: a, balance: byId[a.id] ?? a.openingBalance),
    ];
  }

  Future<int?> lastUsedAccountId({required bool transfer}) async {
    final t = _db.transactions;
    final a = _db.accounts;
    final types = transfer ? const ['transfer'] : const ['income', 'expense'];
    final recent = await (_db.select(t).join([
      innerJoin(a, a.id.equalsExp(t.accountId)),
    ])
          ..where(
            t.transactionType.isIn(types) &
                t.linkedTransactionId.isNull() &
                a.isArchived.equals(false),
          )
          ..orderBy([OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    if (recent != null) return recent.readTable(t).accountId;

    final first = await (_db.select(a)
          ..where((r) => r.isArchived.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.id)])
          ..limit(1))
        .getSingleOrNull();
    return first?.id;
  }

  Future<void> createAdjustment({
    required int accountId,
    required double amount,
    required String date,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: date,
            transactionType: 'adjustment',
            amount: amount,
            accountId: Value(accountId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  AccountModel _toModel(Account row) => AccountModel(
        id: row.id,
        name: row.name,
        color: row.color,
        openingBalance: row.openingBalance,
        isArchived: row.isArchived,
      );
}

final accountDaoProvider = Provider<AccountDao>(
  (ref) => AccountDao(ref.watch(appDatabaseProvider)),
);
