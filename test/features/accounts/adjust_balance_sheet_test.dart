import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_balance.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';
import 'package:pixel_pocket/features/accounts/presentation/screens/widgets/adjust_balance_sheet.dart';

void main() {
  testWidgets('previews the difference to the current balance',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdjustBalanceSheet(
              balance: AccountBalance(
                account: AccountModel(id: 1, name: 'Cash'),
                balance: 85000,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('No change'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '60000');
    await tester.pump();
    expect(find.text('Difference: -Rp 25.000'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '90000');
    await tester.pump();
    expect(find.text('Difference: +Rp 5.000'), findsOneWidget);
  });
}
