import 'package:flare/pages/confirmation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmation page shows domain and runs confirm', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConfirmLoginPage(
          domain: 'example.com',
          action: 'login',
          onConfirm: () async => called = true,
        ),
      ),
    );

    expect(find.text('example.com'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
  });

  testWidgets('confirmation page shows error and allows retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfirmLoginPage(
          domain: 'example.com',
          action: 'login',
          onConfirm: () async => throw Exception('boom'),
        ),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
