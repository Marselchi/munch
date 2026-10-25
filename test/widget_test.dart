import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/app.dart';

void main() {
  testWidgets('App renders home screen with core options', (WidgetTester tester) async {
    await tester.pumpWidget(const MunchkinApp());
    await tester.pumpAndSettle();

    expect(find.text('МАНЧКИН'), findsOneWidget);
    expect(find.text('Создать стол (Ведущий)'), findsOneWidget);
    expect(find.text('Присоединиться к игре'), findsOneWidget);
    expect(find.text('Справочник правил'), findsOneWidget);
  });
}
