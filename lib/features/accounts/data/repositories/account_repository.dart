import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/features/accounts/data/datasources/account_dao.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';

class AccountRepository {
  AccountRepository(this._dao);

  final AccountDao _dao;

  Future<List<AccountModel>> getAll() => _dao.getAll();

  Future<AccountModel?> getById(int id) => _dao.getById(id);

  Future<AccountModel> create({
    required String name,
    String? color,
    required double openingBalance,
  }) =>
      _dao.create(name: name, color: color, openingBalance: openingBalance);

  Future<void> update({
    required int id,
    required String name,
    String? color,
    required double openingBalance,
  }) =>
      _dao.update(
        id: id,
        name: name,
        color: color,
        openingBalance: openingBalance,
      );

  Future<void> setArchived(int id, {required bool archived}) =>
      _dao.setArchived(id, archived: archived);

  Future<void> delete(int id) => _dao.delete(id);

  Future<void> reorder(List<int> ids) => _dao.reorder(ids);

  Future<bool> hasTransactions(int id) => _dao.hasTransactions(id);

  Future<List<AccountBalance>> getBalances() => _dao.getBalances();

  Future<int?> lastUsedAccountId({required bool transfer}) =>
      _dao.lastUsedAccountId(transfer: transfer);

  Future<void> createAdjustment({
    required int accountId,
    required double amount,
    required String date,
  }) =>
      _dao.createAdjustment(accountId: accountId, amount: amount, date: date);
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(accountDaoProvider)),
);
