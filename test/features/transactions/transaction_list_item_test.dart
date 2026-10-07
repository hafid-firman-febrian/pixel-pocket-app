import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/widgets/transaction_list_item.dart';

const _transfer = TransactionModel(
  id: 1,
  transactionDate: '2026-07-01',
  transactionType: 'transfer',
  amount: 500000,
  accountId: 1,
  accountName: 'BCA',
  toAccountId: 2,
  toAccountName: 'Dana',
);

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('a transfer shows its route without a sign', (tester) async {
    await _pump(tester, const TransactionListItem(transaction: _transfer));
    expect(find.text('BCA → Dana'), findsOneWidget);
    expect(find.text('500.000'), findsOneWidget);
  });

  testWidgets('a transfer is signed from an account\'s point of view',
      (tester) async {
    await _pump(
      tester,
      const TransactionListItem(transaction: _transfer, perspectiveAccountId: 2),
    );
    expect(find.text('+500.000'), findsOneWidget);

    await _pump(
      tester,
      const TransactionListItem(transaction: _transfer, perspectiveAccountId: 1),
    );
    expect(find.text('-500.000'), findsOneWidget);
  });

  testWidgets('an adjustment shows its signed amount and account',
      (tester) async {
    await _pump(
      tester,
      const TransactionListItem(
        transaction: TransactionModel(
          id: 2,
          transactionDate: '2026-07-01',
          transactionType: 'adjustment',
          amount: -25000,
          accountId: 3,
          accountName: 'Cash',
        ),
      ),
    );
    expect(find.text('Adjustment'), findsOneWidget);
    expect(find.text('CASH'), findsOneWidget);
    expect(find.text('-25.000'), findsOneWidget);
  });

  testWidgets('an expense shows its category and account', (tester) async {
    await _pump(
      tester,
      const TransactionListItem(
        transaction: TransactionModel(
          id: 3,
          transactionDate: '2026-07-01',
          transactionType: 'expense',
          amount: 18000,
          description: 'kopi',
          categoryName: 'Coffee',
          accountName: 'GoPay',
        ),
      ),
    );
    expect(find.text('kopi'), findsOneWidget);
    expect(find.text('COFFEE · GOPAY'), findsOneWidget);
    expect(find.text('-18.000'), findsOneWidget);
  });
}
