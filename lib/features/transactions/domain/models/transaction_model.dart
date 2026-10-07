class TransactionModel {
  final int id;
  final String transactionDate;
  final String transactionType;
  final double amount;
  final int? categoryId;
  final String? description;
  final String? categoryName;
  final String? categoryColor;
  final int? accountId;
  final String? accountName;
  final int? toAccountId;
  final String? toAccountName;
  final int? linkedTransactionId;
  final double? feeAmount;
  final String? createdAt;
  final String? updatedAt;

  const TransactionModel({
    required this.id,
    required this.transactionDate,
    required this.transactionType,
    required this.amount,
    this.categoryId,
    this.description,
    this.categoryName,
    this.categoryColor,
    this.accountId,
    this.accountName,
    this.toAccountId,
    this.toAccountName,
    this.linkedTransactionId,
    this.feeAmount,
    this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => transactionType == 'income';
  bool get isExpense => transactionType == 'expense';
  bool get isTransfer => transactionType == 'transfer';
  bool get isAdjustment => transactionType == 'adjustment';
  bool get isAdminFee => linkedTransactionId != null;
}
