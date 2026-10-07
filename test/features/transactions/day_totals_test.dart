import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/features/transactions/domain/models/day_totals.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

TransactionModel _tx(String type, double amount) => TransactionModel(
      id: 0,
      transactionDate: '2026-07-01',
      transactionType: type,
      amount: amount,
    );

void main() {
  test('only income and expense are added up', () {
    final totals = DayTotals.of([
      _tx('income', 1000),
      _tx('expense', 300),
      _tx('transfer', 50000),
      _tx('adjustment', -700),
    ]);
    expect(totals.income, 1000);
    expect(totals.expense, 300);
  });
}
