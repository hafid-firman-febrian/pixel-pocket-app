import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/dashboard/data/datasources/summary_dao.dart';

void main() {
  late AppDatabase db;
  late SummaryDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SummaryDao(db);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: const Value(1), name: 'Food', color: const Value('#111111'), type: 'expense'));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: const Value(2), name: 'Transport', color: const Value('#222222'), type: 'expense'));
    Future<void> add(String type, double amt, int? cat, String date) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
            transactionDate: date, transactionType: type, amount: amt, categoryId: Value(cat)));
    await add('income', 1000, null, '2026-07-01');
    await add('expense', 300, 1, '2026-07-02');
    await add('expense', 100, 2, '2026-07-03');
  });
  tearDown(() => db.close());

  test('summary aggregates income/expense/balance/count', () async {
    final s = await dao.getSummary(null);
    expect(s.totalIncome, 1000);
    expect(s.totalExpense, 400);
    expect(s.balance, 600);
    expect(s.transactionCount, 3);
  });

  test('by-category totals with percentage relative to same type', () async {
    final rows = await dao.getByCategory(null);
    final food = rows.firstWhere((r) => r.categoryId == 1);
    expect(food.total, 300);
    expect(food.percentage, closeTo(75, 0.001));
    expect(food.count, 1);
  });

  test('summary respects salary period bounds', () async {
    await db.into(db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
        id: const Value(5), name: 'P', startDate: '2026-07-02', endDate: '2026-07-02'));
    final s = await dao.getSummary(5);
    expect(s.totalExpense, 300);
    expect(s.totalIncome, 0);
    expect(s.transactionCount, 1);
  });

  test('transfers and adjustments stay out of the totals and the count', () async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-04', transactionType: 'transfer', amount: 5000,
        accountId: const Value(1), toAccountId: const Value(2)));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-04', transactionType: 'adjustment', amount: -700,
        accountId: const Value(1)));

    final s = await dao.getSummary(null);
    expect(s.totalIncome, 1000);
    expect(s.totalExpense, 400);
    expect(s.balance, 600);
    expect(s.transactionCount, 3);
    final byCategory = await dao.getByCategory(null);
    expect(byCategory.fold<double>(0, (sum, c) => sum + c.total), 400);
  });

  test('an admin fee counts as an expense in its own category', () async {
    final feeCategory = await db.adminFeeCategoryId();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-04', transactionType: 'expense', amount: 2500,
        categoryId: Value(feeCategory), linkedTransactionId: const Value(1)));

    final s = await dao.getSummary(null);
    expect(s.totalExpense, 2900);
    expect(s.transactionCount, 4);
    final fee = (await dao.getByCategory(null)).firstWhere((c) => c.categoryId == feeCategory);
    expect(fee.total, 2500);
  });
}
