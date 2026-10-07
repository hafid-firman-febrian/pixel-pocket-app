import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/backup/data/backup_serialization.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('transaction row round-trips including nulls', () async {
    final id = await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-05', transactionType: 'expense', amount: 12.5,
        categoryId: const Value(7), description: const Value('kopi')));
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

    final cells = transactionToRow(row);
    expect(cells.first.toString(), id.toString());

    final companion = transactionFromRow(cells);
    expect(companion.amount.value, 12.5);
    expect(companion.categoryId.value, 7);
    expect(companion.description.value, 'kopi');
    expect(companion.id.value, id);
  });

  test('null category and description serialize to empty and back to null', () async {
    final id = await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-06', transactionType: 'income', amount: 100));
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
    final cells = transactionToRow(row);
    expect(cells[4], '');
    final c = transactionFromRow(cells);
    expect(c.categoryId.value, isNull);
    expect(c.description.value, isNull);
  });

  test('category and salary period round-trip', () async {
    final cid = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Food', color: const Value('#111111'), type: 'expense'));
    final crow = await (db.select(db.categories)..where((c) => c.id.equals(cid))).getSingle();
    final cc = categoryFromRow(categoryToRow(crow));
    expect(cc.name.value, 'Food');
    expect(cc.color.value, '#111111');
    expect(cc.type.value, 'expense');

    final pid = await db.into(db.salaryPeriods).insert(
        SalaryPeriodsCompanion.insert(name: 'Jul', startDate: '2026-07-01', endDate: '2026-07-31', salaryAmount: const Value(5000)));
    final prow = await (db.select(db.salaryPeriods)..where((p) => p.id.equals(pid))).getSingle();
    final pc = salaryPeriodFromRow(salaryPeriodToRow(prow));
    expect(pc.salaryAmount.value, 5000);
    expect(pc.name.value, 'Jul');
  });

  test('padRow pads a short salary period row from trimmed sheet values', () {
    final row = padRow(['3', 'Jul', '2026-07-01', '2026-07-31'], salaryPeriodsHeader.length);
    final companion = salaryPeriodFromRow(row);
    expect(companion.salaryAmount.value, isNull);
    expect(companion.name.value, 'Jul');
  });

  test('padRow pads a short transaction row from trimmed sheet values', () {
    final row = padRow(
        ['99', '2026-07-05', 'expense', '12', '7', 'kopi'], transactionsHeader.length);
    final companion = transactionFromRow(row);
    expect(companion.createdAt.value, isNull);
    expect(companion.updatedAt.value, isNull);
  });

  group('remoteSummaryFromMetadataRows', () {
    test('parses counts and last backup time', () {
      final summary = remoteSummaryFromMetadataRows([
        ['key', 'value'],
        ['schema_version', '1'],
        ['last_backup_at', '2026-08-05T21:10:00.000'],
        ['categories', '20'],
        ['salary_periods', '3'],
        ['transactions', '142'],
      ]);
      expect(summary, isNotNull);
      expect(summary!.transactions, 142);
      expect(summary.categories, 20);
      expect(summary.salaryPeriods, 3);
      expect(summary.lastBackupAt, DateTime.parse('2026-08-05T21:10:00.000'));
      expect(summary.isEmpty, false);
    });

    test('returns null when no count key is parsable', () {
      expect(remoteSummaryFromMetadataRows([]), isNull);
      expect(remoteSummaryFromMetadataRows([['key', 'value']]), isNull);
      expect(
        remoteSummaryFromMetadataRows([
          ['key', 'value'],
          ['schema_version', '1'],
          ['transactions', 'abc'],
        ]),
        isNull,
      );
    });

    test('treats all-zero counts as empty and tolerates missing keys', () {
      final summary = remoteSummaryFromMetadataRows([
        ['key', 'value'],
        ['transactions', '0'],
      ]);
      expect(summary, isNotNull);
      expect(summary!.isEmpty, true);
      expect(summary.categories, 0);
      expect(summary.lastBackupAt, isNull);
    });

    test('ignores malformed short rows', () {
      final summary = remoteSummaryFromMetadataRows([
        ['key'],
        [],
        ['transactions', '5'],
      ]);
      expect(summary!.transactions, 5);
    });
  });

  test('account row round-trips', () async {
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: 'Dana', color: const Value('#5F8A8B'),
        openingBalance: const Value(230000), isArchived: const Value(true)));
    final row = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

    final c = accountFromRow(accountToRow(row));
    expect(c.id.value, id);
    expect(c.name.value, 'Dana');
    expect(c.color.value, '#5F8A8B');
    expect(c.openingBalance.value, 230000);
    expect(c.isArchived.value, isTrue);
  });

  test('a padded account row falls back to safe defaults', () {
    final c = accountFromRow(padRow(['4', 'Cash'], accountsHeader.length));
    expect(c.color.value, isNull);
    expect(c.openingBalance.value, 0);
    expect(c.isArchived.value, isFalse);
  });

  test('transaction account columns round-trip', () async {
    final id = await db.into(db.transactions).insert(TransactionsCompanion.insert(
        transactionDate: '2026-07-05', transactionType: 'expense', amount: 2500,
        accountId: const Value(1), toAccountId: const Value(2),
        linkedTransactionId: const Value(3)));
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

    final cells = transactionToRow(row);
    expect(cells.length, transactionsHeader.length);
    final c = transactionFromRow(cells);
    expect(c.accountId.value, 1);
    expect(c.toAccountId.value, 2);
    expect(c.linkedTransactionId.value, 3);
  });

  test('an old 8-column transaction row restores without accounts', () {
    final c = transactionFromRow(padRow(
        ['99', '2026-07-05', 'expense', '12', '7', 'kopi', '', ''],
        transactionsHeader.length));
    expect(c.accountId.value, isNull);
    expect(c.toAccountId.value, isNull);
    expect(c.linkedTransactionId.value, isNull);
    expect(c.categoryId.value, 7);
  });

  test('the remote summary counts accounts', () {
    final s = remoteSummaryFromMetadataRows([
      ['key', 'value'],
      ['accounts', '3'],
    ]);
    expect(s!.accounts, 3);
    expect(s.isEmpty, isFalse);
  });
}
