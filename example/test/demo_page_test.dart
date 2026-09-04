import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_khipu_example/main.dart';

void main() {
  testWidgets('the form builds and gates the launch button on an operationId',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Building at all is half the point: it catches a widget tree that
    // analyzes cleanly but throws at runtime.
    expect(find.text('Launch Khipu'), findsOneWidget);
    expect(find.text('Enter an operationId to launch.'), findsOneWidget);

    FilledButton button() =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button().onPressed, isNull, reason: 'should start disabled');

    // The first text field on the page is operationId, in the Operation card.
    await tester.enterText(find.byType(TextField).first, 'abc123');
    await tester.pump();

    expect(button().onPressed, isNotNull, reason: 'should enable once set');
    expect(find.text('Enter an operationId to launch.'), findsNothing);
  });

  testWidgets('blank input leaves the launch button disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();

    final FilledButton button =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
