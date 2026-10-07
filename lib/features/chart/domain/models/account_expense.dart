class AccountExpense {
  final int? accountId;
  final String name;
  final String? colorHex;
  final double total;
  final double percentage;

  const AccountExpense({
    required this.accountId,
    required this.name,
    required this.colorHex,
    required this.total,
    required this.percentage,
  });

  bool get hasAccount => accountId != null;
}
