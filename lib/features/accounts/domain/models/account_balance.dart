import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';

class AccountBalance {
  final AccountModel account;
  final double balance;

  const AccountBalance({required this.account, required this.balance});
}
