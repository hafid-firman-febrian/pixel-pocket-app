import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/cache/cache_store.dart';
import 'package:pixel_pocket/core/database/app_database.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/auth/application/services/pin_reset_service.dart';
import 'package:pixel_pocket/features/auth/application/services/pin_service.dart';
import 'package:pixel_pocket/features/auth/data/datasources/pin_local_data_source.dart';
import 'package:pixel_pocket/features/auth/data/repositories/pin_repository.dart';
import 'package:pixel_pocket/features/auth/presentation/controllers/pin_controller.dart';
import 'package:pixel_pocket/features/backup/application/services/backup_service.dart';
import 'package:pixel_pocket/features/backup/presentation/controllers/backup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePinService extends PinService {
  _FakePinService() : super(PinRepository(PinLocalDataSource()));

  @override
  Future<bool> hasPin() async => true;
}

class _WipingResetService implements PinResetService {
  _WipingResetService(this.db);

  final AppDatabase db;

  @override
  Future<void> resetForgottenPin() => db.wipeAllData();
}

class _RestoringBackupService implements BackupService {
  _RestoringBackupService(this.db);

  final AppDatabase db;

  @override
  Future<void> restore() => db.replaceAll(
        categories: const [],
        salaryPeriods: const [],
        accounts: [
          AccountsCompanion.insert(
            id: const Value(1),
            name: 'Jago',
            openingBalance: const Value(70000),
          ),
        ],
        transactions: [
          TransactionsCompanion.insert(
            id: const Value(5),
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 1000,
            accountId: const Value(1),
          ),
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        pinServiceProvider.overrideWithValue(_FakePinService()),
        pinResetServiceProvider.overrideWithValue(_WipingResetService(db)),
        backupServiceProvider.overrideWithValue(_RestoringBackupService(db)),
      ],
    );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: const Value(1),
            name: 'BCA',
            openingBalance: const Value(100000),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 2000,
            accountId: const Value(1),
          ),
        );
    container.listen(accountsProvider, (_, _) {});
    container.listen(accountBalancesProvider, (_, _) {});
    container.listen(lastUsedAccountIdProvider(false), (_, _) {});
    expect((await container.read(accountsProvider.future)).single.name, 'BCA');
    expect(
      (await container.read(accountBalancesProvider.future)).single.balance,
      98000,
    );
    expect(await container.read(lastUsedAccountIdProvider(false).future), 1);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a forgot-PIN wipe drops the cached accounts and balances', () async {
    await container.read(pinControllerProvider.notifier).resetForgottenPin();

    expect(await container.read(accountsProvider.future), isEmpty);
    expect(await container.read(accountBalancesProvider.future), isEmpty);
    expect(
      await container.read(lastUsedAccountIdProvider(false).future),
      isNull,
    );
  });

  test('restoring a backup replaces the cached accounts and balances',
      () async {
    container.listen(backupControllerProvider, (_, _) {});

    expect(
      await container.read(backupControllerProvider.notifier).restore(),
      isTrue,
    );

    expect(
      (await container.read(accountsProvider.future)).map((a) => a.name),
      ['Jago'],
    );
    expect(
      (await container.read(accountBalancesProvider.future)).single.balance,
      69000,
    );
  });
}
