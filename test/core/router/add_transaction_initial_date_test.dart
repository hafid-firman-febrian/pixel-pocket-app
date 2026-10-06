import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/router/app_router.dart';

void main() {
  final now = DateTime(2026, 10, 6, 21, 45);

  test('the Transactions tab defers to its visible range', () {
    expect(
      addTransactionInitialDate(currentPath: AppRoutes.transactions, now: now),
      isNull,
    );
  });

  test('every other tab defaults to today without a time part', () {
    for (final path in [
      AppRoutes.dashboard,
      AppRoutes.chart,
      AppRoutes.settings,
    ]) {
      expect(
        addTransactionInitialDate(currentPath: path, now: now),
        DateTime(2026, 10, 6),
        reason: path,
      );
    }
  });
}
