// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_opd/main.dart';

void main() {
  testWidgets('shows the SmartOPD output screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SmartOPD'), findsOneWidget);
    expect(find.text('SmartOPD is ready'), findsOneWidget);
  });
}
