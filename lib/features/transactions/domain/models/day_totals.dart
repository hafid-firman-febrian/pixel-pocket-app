import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

class DayTotals {
  final double income;
  final double expense;

  const DayTotals({required this.income, required this.expense});

  factory DayTotals.of(Iterable<TransactionModel> items) {
    var income = 0.0;
    var expense = 0.0;
    for (final t in items) {
      if (t.isIncome) {
        income += t.amount;
      } else if (t.isExpense) {
        expense += t.amount;
      }
    }
    return DayTotals(income: income, expense: expense);
  }
}
