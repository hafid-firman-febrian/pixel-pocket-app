import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/chart/application/services/chart_service.dart';
import 'package:pixel_pocket/features/chart/data/datasources/chart_dao.dart';
import 'package:pixel_pocket/features/chart/data/repositories/chart_repository.dart';

void main() {
  late AppDatabase db;
  late ChartService service;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ChartService(ChartRepository(ChartDao(db)));
  });
  tearDown(() => db.close());

  Future<void> expense(double amount, {int? account}) =>
      db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              transactionDate: today,
              transactionType: 'expense',
              amount: amount,
              accountId: Value(account),
            ),
          );

  test('is empty when no expense has an account', () async {
    await expense(5000);
    expect(await service.expenseByAccount(filter: 'month'), isEmpty);
  });

  test('sorts accounts by total, largest first', () async {
    final bca =
        await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'BCA'));
    final gopay = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'GoPay'));
    await expense(100, account: bca);
    await expense(300, account: gopay);
    await expense(200);

    final items = await service.expenseByAccount(filter: 'month');
    expect(items.map((i) => i.name), ['GoPay', 'No account', 'BCA']);
  });
}
