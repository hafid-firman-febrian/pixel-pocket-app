class AccountModel {
  final int id;
  final String name;
  final String? color;
  final double openingBalance;
  final bool isArchived;

  const AccountModel({
    required this.id,
    required this.name,
    this.color,
    this.openingBalance = 0,
    this.isArchived = false,
  });
}
