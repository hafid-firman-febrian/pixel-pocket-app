import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/features/accounts/application/services/account_service.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/backup/application/auto_backup_coordinator.dart';
import 'package:pixel_pocket/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';

class AccountController {
  AccountController(this._ref);

  final Ref _ref;

  AccountService get _service => _ref.read(accountServiceProvider);

  Future<bool> hasTransactions(int id) => _service.hasTransactions(id);

  Future<void> create({
    required String name,
    String? color,
    required double openingBalance,
  }) async {
    await _service.create(
      name: name,
      color: color,
      openingBalance: openingBalance,
    );
    _afterChange();
  }

  Future<void> update({
    required int id,
    required String name,
    String? color,
    required double openingBalance,
  }) async {
    await _service.update(
      id: id,
      name: name,
      color: color,
      openingBalance: openingBalance,
    );
    _afterChange();
  }

  Future<AccountRemoval> remove(int id) async {
    final result = await _service.remove(id);
    _afterChange();
    return result;
  }

  Future<void> unarchive(int id) async {
    await _service.unarchive(id);
    _afterChange();
  }

  Future<bool> adjustBalance({
    required int accountId,
    required double actualBalance,
  }) async {
    final created = await _service.adjustBalance(
      accountId: accountId,
      actualBalance: actualBalance,
    );
    if (created) _afterChange();
    return created;
  }

  void _afterChange() {
    _ref.invalidate(accountsProvider);
    _ref.invalidate(accountBalancesProvider);
    _ref.invalidate(transactionsControllerProvider);
    _ref.read(transactionsRevisionProvider.notifier).state++;
    unawaited(_ref.read(autoBackupCoordinatorProvider).markDirty());
  }
}

final accountControllerProvider = Provider<AccountController>(
  (ref) => AccountController(ref),
);
