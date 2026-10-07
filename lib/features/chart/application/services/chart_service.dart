import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/features/chart/data/repositories/chart_repository.dart';
import 'package:pixel_pocket/features/chart/domain/models/account_expense.dart';
import 'package:pixel_pocket/features/chart/domain/models/chart_data.dart';

class ChartService {
  ChartService(this._repo);

  final ChartRepository _repo;

  Future<ChartData> chart({String? filter, int? salaryPeriodId}) =>
      _repo.getChart(filter: filter, salaryPeriodId: salaryPeriodId);

  Future<List<AccountExpense>> expenseByAccount({
    String? filter,
    int? salaryPeriodId,
  }) async {
    final items = await _repo.getExpenseByAccount(
      filter: filter,
      salaryPeriodId: salaryPeriodId,
    );
    if (!items.any((i) => i.hasAccount)) return const [];
    return [...items]..sort((a, b) => b.total.compareTo(a.total));
  }
}

final chartServiceProvider = Provider<ChartService>(
  (ref) => ChartService(ref.watch(chartRepositoryProvider)),
);
