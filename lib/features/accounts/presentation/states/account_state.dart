import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/features/accounts/application/services/account_service.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';

final accountsProvider = FutureProvider<List<AccountModel>>((ref) {
  return ref.watch(accountServiceProvider).list();
});

final activeAccountsProvider = FutureProvider<List<AccountModel>>((ref) async {
  final all = await ref.watch(accountsProvider.future);
  return all.where((a) => !a.isArchived).toList();
});

final accountBalancesProvider = FutureProvider<List<AccountBalance>>((ref) {
  ref.watch(transactionsRevisionProvider);
  return ref.watch(accountServiceProvider).balances();
});

final lastUsedAccountIdProvider = FutureProvider.family<int?, bool>((
  ref,
  transfer,
) {
  ref.watch(transactionsRevisionProvider);
  return ref
      .watch(accountServiceProvider)
      .lastUsedAccountId(transfer: transfer);
});
