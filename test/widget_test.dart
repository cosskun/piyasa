import 'package:flutter_test/flutter_test.dart';
import 'package:piyasa/main.dart';

void main() {
  testWidgets('Piyasa App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PiyasaApp());
    expect(find.text('PİYASA'), findsOneWidget);
  });
}
