import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/chart/data/datasources/chart_dao.dart';

void main() {
  late AppDatabase db;
  late ChartDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChartDao(db);
    Future<void> add(String type, double amt, String date) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: date, transactionType: type, amount: amt));
    await add('income', 500, '2026-07-10');
    await add('expense', 200, '2026-07-10');
    await add('expense', 50, '2026-07-12');
  });
  tearDown(() => db.close());

  test('month filter returns one label per day with aligned totals', () async {
    final data = await dao.getChart(filter: 'month', today: DateTime(2026, 7, 15));
    expect(data.labels.length, 31);
    final i10 = data.labels.indexOf('2026-07-10');
    expect(i10, greaterThanOrEqualTo(0));
    expect(data.income[i10], 500);
    expect(data.expense[i10], 200);
    final i11 = data.labels.indexOf('2026-07-11');
    expect(data.expense[i11], 0);
  });

  test('year filter returns 12 monthly buckets', () async {
    final data = await dao.getChart(filter: 'year', today: DateTime(2026, 7, 15));
    expect(data.labels.length, 12);
    final jul = data.labels.indexOf('2026-07');
    expect(data.expense[jul], 250);
    expect(data.income[jul], 500);
  });

  test('salary period uses its bounds daily', () async {
    await db.into(db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
      id: const Value(3), name: 'P', startDate: '2026-07-10', endDate: '2026-07-12'));
    final data = await dao.getChart(salaryPeriodId: 3, today: DateTime(2026, 7, 15));
    expect(data.labels, ['2026-07-10', '2026-07-11', '2026-07-12']);
    expect(data.expense[0], 200);
    expect(data.expense[2], 50);
  });

  test('transfers and adjustments are not plotted', () async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-10', transactionType: 'transfer', amount: 999,
        accountId: const Value(1), toAccountId: const Value(2)));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-10', transactionType: 'adjustment', amount: -999,
        accountId: const Value(1)));

    final data = await dao.getChart(filter: 'month', today: DateTime(2026, 7, 15));
    final i10 = data.labels.indexOf('2026-07-10');
    expect(data.income[i10], 500);
    expect(data.expense[i10], 200);
  });

  test('expense by account follows the range and keeps legacy rows as No account',
      () async {
    final bca = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'BCA', color: const Value('#123456')));
    final gopay = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'GoPay'));
    Future<void> add(String type, double amt, String date, {int? account, int? to}) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
            transactionDate: date, transactionType: type, amount: amt,
            accountId: Value(account), toAccountId: Value(to)));
    await add('expense', 300, '2026-07-11', account: gopay);
    await add('expense', 100, '2026-07-11', account: bca);
    await add('transfer', 9999, '2026-07-11', account: bca, to: gopay);
    await add('adjustment', -9999, '2026-07-11', account: bca);
    await add('expense', 999, '2026-06-30', account: bca);

    final items = await dao.getExpenseByAccount(filter: 'month', today: DateTime(2026, 7, 15));
    final byName = {for (final i in items) i.name: i};
    expect(byName.keys, unorderedEquals(['GoPay', 'BCA', 'No account']));
    expect(byName['GoPay']!.total, 300);
    expect(byName['BCA']!.total, 100);
    expect(byName['BCA']!.colorHex, '#123456');
    expect(byName['No account']!.total, 250);
    expect(byName['No account']!.hasAccount, isFalse);
    expect(byName['GoPay']!.percentage, closeTo(300 / 650 * 100, 0.001));
  });

  test('expense by account uses salary period bounds', () async {
    await db.into(db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
      id: const Value(3), name: 'P', startDate: '2026-07-12', endDate: '2026-07-12'));
    final items = await dao.getExpenseByAccount(salaryPeriodId: 3, today: DateTime(2026, 7, 15));
    expect(items.single.total, 50);
  });
}
