import 'package:flutter_test/flutter_test.dart';
import 'package:echoguard/main.dart';

void main() {
  testWidgets('Dashboard loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const EchoGuardApp());
    expect(find.text('EchoGuard Dashboard'), findsOneWidget);
  });
}