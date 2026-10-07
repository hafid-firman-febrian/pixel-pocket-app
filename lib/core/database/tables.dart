import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get type => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SalaryPeriods extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  RealColumn get salaryAmount => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  IntColumn get id => integer()();
  TextColumn get transactionDate => text()();
  TextColumn get transactionType => text()();
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  IntColumn get accountId => integer().nullable()();
  IntColumn get toAccountId => integer().nullable()();
  IntColumn get linkedTransactionId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
