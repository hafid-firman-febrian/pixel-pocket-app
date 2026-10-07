import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/widgets/pixel_select_chip.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/categories/domain/models/category_model.dart';
import 'package:pixel_pocket/features/categories/presentation/states/category_state.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/widgets/transaction_form_sheet.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';

class _IdleTransactionsController extends TransactionsController {
  @override
  Future<List<TransactionModel>> build() async => const [];
}

const _bca = AccountModel(id: 1, name: 'BCA');
const _gopay = AccountModel(id: 2, name: 'GoPay');
const _old = AccountModel(id: 3, name: 'Old', isArchived: true);

Widget _host(
  TransactionFormSheet sheet, {
  List<AccountModel> accounts = const [],
  int? lastUsed,
  int? lastTransferFrom,
}) =>
    ProviderScope(
      overrides: [
        categoriesProvider.overrideWith((ref) async => const <CategoryModel>[]),
        accountsProvider.overrideWith((ref) async => accounts),
        lastUsedAccountIdProvider.overrideWith(
          (ref, transfer) async => transfer ? lastTransferFrom : lastUsed,
        ),
        transactionsControllerProvider
            .overrideWith(_IdleTransactionsController.new),
        rangeFilterProvider.overrideWith(
          (ref) => RangeFilter(unit: RangeUnit.month, anchor: DateTime(2025, 3, 1)),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: sheet)),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Finder _chip(String label) => find.widgetWithText(PixelSelectChip, label);

bool _selected(WidgetTester tester, String label) =>
    tester.widget<PixelSelectChip>(_chip(label)).selected;

void main() {
  testWidgets('initialDate wins over the range-based default', (tester) async {
    await tester.pumpWidget(
      _host(TransactionFormSheet(initialDate: DateTime(2026, 1, 15))),
    );
    await tester.pump();
    expect(find.text('2026-01-15'), findsOneWidget);
  });

  testWidgets('without initialDate the date follows the Transactions range',
      (tester) async {
    await tester.pumpWidget(_host(const TransactionFormSheet()));
    await tester.pump();
    expect(find.text('2025-03-31'), findsOneWidget);
  });

  testWidgets('without accounts there is no ACCOUNT field and no TRANSFER',
      (tester) async {
    await tester.pumpWidget(_host(const TransactionFormSheet()));
    await _settle(tester);
    expect(find.text('ACCOUNT'), findsNothing);
    expect(find.text('TRANSFER'), findsNothing);
  });

  testWidgets('TRANSFER is hidden with one active account', (tester) async {
    await tester.pumpWidget(
      _host(const TransactionFormSheet(), accounts: const [_bca, _old]),
    );
    await _settle(tester);
    expect(find.text('TRANSFER'), findsNothing);
  });

  testWidgets('TRANSFER shows with two active accounts', (tester) async {
    await tester.pumpWidget(
      _host(const TransactionFormSheet(), accounts: const [_bca, _gopay]),
    );
    await _settle(tester);
    expect(find.text('TRANSFER'), findsOneWidget);
  });

  testWidgets('ACCOUNT starts on the last used account', (tester) async {
    await tester.pumpWidget(
      _host(
        const TransactionFormSheet(),
        accounts: const [_bca, _gopay],
        lastUsed: 2,
      ),
    );
    await _settle(tester);
    expect(_selected(tester, 'GoPay'), isTrue);
    expect(_selected(tester, 'BCA'), isFalse);
    expect(_chip('No account'), findsNothing);
  });

  testWidgets('archived accounts are not offered for new transactions',
      (tester) async {
    await tester.pumpWidget(
      _host(const TransactionFormSheet(), accounts: const [_bca, _old]),
    );
    await _settle(tester);
    expect(_chip('BCA'), findsOneWidget);
    expect(_chip('Old'), findsNothing);
  });

  testWidgets('editing a legacy transaction starts on No account',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const TransactionFormSheet(
          existing: TransactionModel(
            id: 7,
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 12000,
            categoryId: 1,
          ),
        ),
        accounts: const [_bca, _gopay],
        lastUsed: 2,
      ),
    );
    await _settle(tester);
    expect(_selected(tester, 'No account'), isTrue);
    expect(_selected(tester, 'GoPay'), isFalse);
  });

  testWidgets('editing keeps an archived account selected', (tester) async {
    await tester.pumpWidget(
      _host(
        const TransactionFormSheet(
          existing: TransactionModel(
            id: 8,
            transactionDate: '2026-07-01',
            transactionType: 'expense',
            amount: 12000,
            categoryId: 1,
            accountId: 3,
          ),
        ),
        accounts: const [_bca, _old],
      ),
    );
    await _settle(tester);
    expect(_selected(tester, 'Old'), isTrue);
    expect(find.text('TRANSFER'), findsNothing);
  });

  testWidgets('TO never offers the FROM account', (tester) async {
    await tester.pumpWidget(
      _host(
        const TransactionFormSheet(),
        accounts: const [_bca, _gopay],
        lastUsed: 2,
        lastTransferFrom: 1,
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('TRANSFER'));
    await _settle(tester);

    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('ADMIN FEE (OPTIONAL)'), findsOneWidget);
    expect(find.text('CATEGORY'), findsNothing);
    expect(_chip('BCA'), findsOneWidget);
    expect(_selected(tester, 'BCA'), isTrue);
    expect(_chip('GoPay'), findsNWidgets(2));
  });

  testWidgets('editing a transfer shows only TRANSFER and its fee',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const TransactionFormSheet(
          existing: TransactionModel(
            id: 9,
            transactionDate: '2026-07-01',
            transactionType: 'transfer',
            amount: 50000,
            accountId: 1,
            toAccountId: 2,
            feeAmount: 2500,
          ),
        ),
        accounts: const [_bca, _gopay],
      ),
    );
    await _settle(tester);
    expect(find.text('TRANSFER'), findsOneWidget);
    expect(find.text('EXPENSE'), findsNothing);
    expect(find.text('2.500'), findsOneWidget);
  });
}
