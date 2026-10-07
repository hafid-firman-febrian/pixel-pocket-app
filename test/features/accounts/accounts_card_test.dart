import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/accounts_card.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/dashboard/presentation/states/dashboard_state.dart';

AccountBalance _b(int id, String name, double balance, {bool archived = false}) =>
    AccountBalance(
      account: AccountModel(id: id, name: name, isArchived: archived),
      balance: balance,
    );

Future<void> _pump(
  WidgetTester tester,
  List<AccountBalance> items, {
  bool hidden = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountBalancesProvider.overrideWith((ref) async => items),
        balanceHiddenProvider.overrideWith((ref) => hidden),
      ],
      child: const MaterialApp(home: Scaffold(body: AccountsCard())),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('lists active accounts with a total', (tester) async {
    await _pump(tester, [
      _b(1, 'BCA', 92500),
      _b(2, 'Dana', 31000),
      _b(3, 'Old', 5000, archived: true),
    ]);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Dana'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
    expect(find.text('Rp 92.500'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Rp 123.500'), findsOneWidget);
  });

  testWidgets('a negative balance shows a minus sign', (tester) async {
    await _pump(tester, [_b(1, 'Cash', -2000)]);
    expect(find.text('-Rp 2.000'), findsNWidgets(2));
  });

  testWidgets('hidden balances are masked', (tester) async {
    await _pump(tester, [_b(1, 'Cash', -2000)], hidden: true);
    expect(find.text('Rp ******'), findsNWidgets(2));
    expect(find.textContaining('2.000'), findsNothing);
  });

  testWidgets('no accounts offers to add one', (tester) async {
    await _pump(tester, [_b(3, 'Old', 0, archived: true)]);
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.text('ADD ACCOUNT'), findsOneWidget);
  });
}
