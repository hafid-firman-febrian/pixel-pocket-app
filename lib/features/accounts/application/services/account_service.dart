import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/features/accounts/data/repositories/account_repository.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';

enum AccountRemoval { deleted, archived }

class AccountService {
  AccountService(this._repo);

  final AccountRepository _repo;

  Future<List<AccountModel>> list() => _repo.getAll();

  Future<List<AccountBalance>> balances() => _repo.getBalances();

  Future<int?> lastUsedAccountId({required bool transfer}) =>
      _repo.lastUsedAccountId(transfer: transfer);

  Future<bool> hasTransactions(int id) => _repo.hasTransactions(id);

  Future<AccountModel> create({
    required String name,
    String? color,
    double openingBalance = 0,
  }) async {
    final valid = await _validName(name);
    return _repo.create(
      name: valid,
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
    final valid = await _validName(name, exceptId: id);
    await _repo.update(
      id: id,
      name: valid,
      color: color,
      openingBalance: openingBalance,
    );
  }

  Future<AccountRemoval> remove(int id) async {
    if (await _repo.hasTransactions(id)) {
      await _repo.setArchived(id, archived: true);
      return AccountRemoval.archived;
    }
    await _repo.delete(id);
    return AccountRemoval.deleted;
  }

  Future<void> unarchive(int id) => _repo.setArchived(id, archived: false);

  Future<bool> adjustBalance({
    required int accountId,
    required double actualBalance,
    DateTime? today,
  }) async {
    final balances = await _repo.getBalances();
    final current = balances
        .where((b) => b.account.id == accountId)
        .firstOrNull;
    if (current == null) {
      throw const Failure(
        message: 'Account not found.',
        type: FailureType.notFound,
      );
    }
    final diff = actualBalance - current.balance;
    if (diff == 0) return false;
    await _repo.createAdjustment(
      accountId: accountId,
      amount: diff,
      date: DateFormat('yyyy-MM-dd').format(today ?? DateTime.now()),
    );
    return true;
  }

  Future<String> _validName(String name, {int? exceptId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const Failure(message: 'Enter an account name.');
    }
    final all = await _repo.getAll();
    final taken = all.any(
      (a) => a.id != exceptId && a.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (taken) {
      throw Failure(message: 'An account named "$trimmed" already exists.');
    }
    return trimmed;
  }
}

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(ref.watch(accountRepositoryProvider)),
);
