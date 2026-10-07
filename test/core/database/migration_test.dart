import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/core/database/default_categories.dart';

const _v1Schema = [
  'CREATE TABLE "categories" ("id" INTEGER NOT NULL, "name" TEXT NOT NULL, '
      '"color" TEXT NULL, "type" TEXT NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "salary_periods" ("id" INTEGER NOT NULL, "name" TEXT NOT NULL, '
      '"start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, '
      '"salary_amount" REAL NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "transactions" ("id" INTEGER NOT NULL, '
      '"transaction_date" TEXT NOT NULL, "transaction_type" TEXT NOT NULL, '
      '"amount" REAL NOT NULL, "category_id" INTEGER NULL, '
      '"description" TEXT NULL, "created_at" TEXT NULL, '
      '"updated_at" TEXT NULL, PRIMARY KEY ("id"))',
];

const _v2Schema = [
  'CREATE TABLE "categories" ("id" INTEGER NOT NULL, "name" TEXT NOT NULL, '
      '"color" TEXT NULL, "type" TEXT NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "salary_periods" ("id" INTEGER NOT NULL, "name" TEXT NOT NULL, '
      '"start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, '
      '"salary_amount" REAL NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "transactions" ("id" INTEGER NOT NULL, '
      '"transaction_date" TEXT NOT NULL, "transaction_type" TEXT NOT NULL, '
      '"amount" REAL NOT NULL, "category_id" INTEGER NULL, '
      '"description" TEXT NULL, "created_at" TEXT NULL, '
      '"updated_at" TEXT NULL, "account_id" INTEGER NULL, '
      '"to_account_id" INTEGER NULL, "linked_transaction_id" INTEGER NULL, '
      'PRIMARY KEY ("id"))',
  'CREATE TABLE "accounts" ("id" INTEGER NOT NULL, "name" TEXT NOT NULL, '
      '"color" TEXT NULL, "opening_balance" REAL NOT NULL DEFAULT 0.0, '
      '"is_archived" INTEGER NOT NULL DEFAULT 0 '
      'CHECK ("is_archived" IN (0, 1)), PRIMARY KEY ("id"))',
];

AppDatabase _openV2() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final sql in _v2Schema) {
          raw.execute(sql);
        }
        raw.execute(
          "INSERT INTO categories (id, name, color, type) VALUES "
          "(1, 'Food', '#111111', 'expense'), "
          "(19, 'Admin Fee', '#8C6B6B', 'expense')",
        );
        raw.execute(
          "INSERT INTO accounts (id, name, color, opening_balance, is_archived) "
          "VALUES (1, 'BCA', '#386694', 100000, 0), (2, 'Dana', NULL, 0, 0)",
        );
        raw.execute(
          "INSERT INTO transactions (id, transaction_date, transaction_type, "
          "amount, account_id, to_account_id) "
          "VALUES (7, '2026-10-01', 'transfer', 30000, 1, 2)",
        );
        raw.execute('PRAGMA user_version = 2');
      },
    ),
  );
}

AppDatabase _openV1({required bool withCategories}) {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final sql in _v1Schema) {
          raw.execute(sql);
        }
        if (withCategories) {
          raw.execute(
            "INSERT INTO categories (id, name, color, type) "
            "VALUES (1, 'Food', '#111111', 'expense')",
          );
        }
        raw.execute(
          "INSERT INTO transactions "
          "(id, transaction_date, transaction_type, amount, category_id) "
          "VALUES (5, '2026-07-01', 'expense', 12000, 1)",
        );
        raw.execute('PRAGMA user_version = 1');
      },
    ),
  );
}

void main() {
  test('upgrading from v1 keeps old rows and adds the account columns as null',
      () async {
    final db = _openV1(withCategories: true);
    addTearDown(db.close);

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.id, 5);
    expect(tx.amount, 12000);
    expect(tx.categoryId, 1);
    expect(tx.accountId, isNull);
    expect(tx.toAccountId, isNull);
    expect(tx.linkedTransactionId, isNull);
    expect(await db.select(db.accounts).get(), isEmpty);
  });

  test('upgrading from v1 adds the Admin Fee category exactly once', () async {
    final db = _openV1(withCategories: true);
    addTearDown(db.close);

    final cats = await db.select(db.categories).get();
    expect(cats.map((c) => c.name), containsAll(['Food', adminFeeCategoryName]));
    expect(cats.where((c) => c.name == adminFeeCategoryName).length, 1);
    final feeId = cats.firstWhere((c) => c.name == adminFeeCategoryName).id;
    expect(await db.adminFeeCategoryId(), feeId);
  });

  test('upgrading a v1 database without categories still lets the seed run',
      () async {
    final db = _openV1(withCategories: false);
    addTearDown(db.close);

    expect(await db.select(db.categories).get(), isEmpty);
    await db.seedDefaultCategoriesIfEmpty();
    expect((await db.select(db.categories).get()).length, 19);
  });

  test('accounts can be written after the upgrade', () async {
    final db = _openV1(withCategories: true);
    addTearDown(db.close);

    final id = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'BCA'));
    final row = await (db.select(db.accounts)..where((a) => a.id.equals(id)))
        .getSingle();
    expect(row.openingBalance, 0);
    expect(row.isArchived, isFalse);
    expect(row.sortOrder, 0);
  });

  test('upgrading from v2 adds the account order and keeps every row', () async {
    final db = _openV2();
    addTearDown(db.close);

    final accounts = await (db.select(db.accounts)
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.id)]))
        .get();
    expect(accounts.map((a) => a.name), ['BCA', 'Dana']);
    expect(accounts.map((a) => a.sortOrder), [0, 0]);
    expect(accounts.first.openingBalance, 100000);
    expect(accounts.first.color, '#386694');

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.transactionType, 'transfer');
    expect(tx.accountId, 1);
    expect(tx.toAccountId, 2);

    final fees = await (db.select(db.categories)
          ..where((c) => c.name.equals(adminFeeCategoryName)))
        .get();
    expect(fees.length, 1);
  });
}
