import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';

void main() {
  testWidgets('bottomInset adds s16 to the MediaQuery bottom padding',
      (tester) async {
    late double inset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 90)),
        child: Builder(
          builder: (context) {
            inset = AppSpacing.bottomInset(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(inset, 90 + AppSpacing.s16);
  });
}
