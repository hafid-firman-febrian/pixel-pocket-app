import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/chart/domain/models/account_expense.dart';
import 'package:pixel_pocket/features/chart/domain/models/chart_data.dart';

typedef _ChartRange = ({DateTime start, DateTime end, bool monthly});

class ChartDao {
  ChartDao(this._db);

  final AppDatabase _db;

  static final _day = DateFormat('yyyy-MM-dd');
  static final _month = DateFormat('yyyy-MM');

  Future<ChartData> getChart({
    String? filter,
    int? salaryPeriodId,
    DateTime? today,
  }) async {
    final range = await _range(
      filter: filter,
      salaryPeriodId: salaryPeriodId,
      today: today,
    );
    return range.monthly
        ? _monthly(range.start.year)
        : _daily(range.start, range.end);
  }

  Future<List<AccountExpense>> getExpenseByAccount({
    String? filter,
    int? salaryPeriodId,
    DateTime? today,
  }) async {
    final range = await _range(
      filter: filter,
      salaryPeriodId: salaryPeriodId,
      today: today,
    );
    final rows = await _rowsBetween(
      _day.format(range.start),
      _day.format(range.end),
    );
    final accounts = await _db.select(_db.accounts).get();
    final byId = {for (final a in accounts) a.id: a};

    final totals = <int?, double>{};
    for (final r in rows) {
      if (r.transactionType != 'expense') continue;
      totals[r.accountId] = (totals[r.accountId] ?? 0) + r.amount;
    }
    final grand = totals.values.fold<double>(0, (sum, v) => sum + v);

    return [
      for (final e in totals.entries)
        AccountExpense(
          accountId: e.key,
          name: e.key == null
              ? 'No account'
              : (byId[e.key]?.name ?? 'Unknown'),
          colorHex: byId[e.key]?.color,
          total: e.value,
          percentage: grand == 0 ? 0 : e.value / grand * 100,
        ),
    ];
  }

  Future<_ChartRange> _range({
    String? filter,
    int? salaryPeriodId,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final anchor = DateTime(now.year, now.month, now.day);

    if (salaryPeriodId != null) {
      final p = await (_db.select(_db.salaryPeriods)
            ..where((r) => r.id.equals(salaryPeriodId)))
          .getSingleOrNull();
      if (p != null) {
        return (
          start: DateTime.parse(p.startDate),
          end: DateTime.parse(p.endDate),
          monthly: false,
        );
      }
    }

    switch (filter ?? 'month') {
      case 'week':
        final start = anchor.subtract(Duration(days: anchor.weekday - 1));
        return (
          start: start,
          end: start.add(const Duration(days: 6)),
          monthly: false,
        );
      case 'year':
        return (
          start: DateTime(anchor.year, 1, 1),
          end: DateTime(anchor.year, 12, 31),
          monthly: true,
        );
      case 'month':
      default:
        return (
          start: DateTime(anchor.year, anchor.month, 1),
          end: DateTime(anchor.year, anchor.month + 1, 0),
          monthly: false,
        );
    }
  }

  Future<ChartData> _daily(DateTime start, DateTime end) async {
    final rows = await _rowsBetween(_day.format(start), _day.format(end));
    final labels = <String>[];
    final incomeByKey = <String, double>{};
    final expenseByKey = <String, double>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      labels.add(_day.format(d));
    }
    for (final r in rows) {
      final key = r.transactionDate;
      if (r.transactionType == 'income') {
        incomeByKey[key] = (incomeByKey[key] ?? 0) + r.amount;
      } else if (r.transactionType == 'expense') {
        expenseByKey[key] = (expenseByKey[key] ?? 0) + r.amount;
      }
    }
    return ChartData(
      labels: labels,
      income: labels.map((k) => incomeByKey[k] ?? 0).toList(),
      expense: labels.map((k) => expenseByKey[k] ?? 0).toList(),
    );
  }

  Future<ChartData> _monthly(int year) async {
    final rows = await _rowsBetween('$year-01-01', '$year-12-31');
    final labels = [for (var m = 1; m <= 12; m++) _month.format(DateTime(year, m))];
    final incomeByKey = <String, double>{};
    final expenseByKey = <String, double>{};
    for (final r in rows) {
      final key = r.transactionDate.substring(0, 7);
      if (r.transactionType == 'income') {
        incomeByKey[key] = (incomeByKey[key] ?? 0) + r.amount;
      } else if (r.transactionType == 'expense') {
        expenseByKey[key] = (expenseByKey[key] ?? 0) + r.amount;
      }
    }
    return ChartData(
      labels: labels,
      income: labels.map((k) => incomeByKey[k] ?? 0).toList(),
      expense: labels.map((k) => expenseByKey[k] ?? 0).toList(),
    );
  }

  Future<List<Transaction>> _rowsBetween(String start, String end) {
    return (_db.select(_db.transactions)
          ..where((t) => t.transactionDate.isBiggerOrEqualValue(start))
          ..where((t) => t.transactionDate.isSmallerOrEqualValue(end)))
        .get();
  }
}

final chartDaoProvider = Provider<ChartDao>(
  (ref) => ChartDao(ref.watch(appDatabaseProvider)),
);
