import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/core/database/default_categories.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds 19 default categories when empty', () async {
    await db.seedDefaultCategoriesIfEmpty();
    final rows = await db.select(db.categories).get();
    expect(rows.length, 19);
    expect(rows.where((c) => c.type == 'income').length, 5);
    expect(rows.where((c) => c.type == 'expense').length, 14);
    expect(rows.first.color, startsWith('#'));
    expect(rows.last.name, adminFeeCategoryName);
  });

  test('seed is idempotent', () async {
    await db.seedDefaultCategoriesIfEmpty();
    await db.seedDefaultCategoriesIfEmpty();
    final rows = await db.select(db.categories).get();
    expect(rows.length, 19);
  });

  test('adminFeeCategoryId returns the seeded Admin Fee category', () async {
    await db.seedDefaultCategoriesIfEmpty();
    final id = await db.adminFeeCategoryId();
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id)))
        .getSingle();
    expect(row.name, adminFeeCategoryName);
    expect((await db.select(db.categories).get()).length, 19);
  });

  test('adminFeeCategoryId recreates the category when it was deleted',
      () async {
    await db.seedDefaultCategoriesIfEmpty();
    await (db.delete(db.categories)
          ..where((c) => c.name.equals(adminFeeCategoryName)))
        .go();
    final id = await db.adminFeeCategoryId();
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id)))
        .getSingle();
    expect(row.name, adminFeeCategoryName);
    expect(row.type, 'expense');
    expect(row.color, adminFeeCategoryColor);
  });
}
