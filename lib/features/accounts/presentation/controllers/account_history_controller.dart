import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/features/transactions/application/services/transaction_service.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_filter.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';

class AccountHistoryController
    extends AutoDisposeFamilyAsyncNotifier<List<TransactionModel>, int> {
  static const int pageSize = 20;

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<TransactionModel>> build(int accountId) async {
    ref.watch(transactionsRevisionProvider);
    _page = 1;
    final items = await _list(1);
    _hasMore = items.length == pageSize;
    return items;
  }

  Future<List<TransactionModel>> _list(int page) => ref
      .read(transactionServiceProvider)
      .list(TransactionFilter(accountId: arg, page: page, limit: pageSize));

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || !state.hasValue) return;
    _loadingMore = true;
    try {
      final next = await _list(_page + 1);
      _page += 1;
      _hasMore = next.length == pageSize;
      state = AsyncData([...?state.valueOrNull, ...next]);
    } finally {
      _loadingMore = false;
    }
  }
}

final accountHistoryControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AccountHistoryController, List<TransactionModel>, int>(
  AccountHistoryController.new,
);
