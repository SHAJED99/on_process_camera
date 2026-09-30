import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home lists every test screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Photo capture'), findsOneWidget);
    expect(find.text('Liveness + video'), findsOneWidget);
    expect(find.text('SDK liveness flow'), findsOneWidget);
    expect(find.text('Camera lifecycle'), findsOneWidget);
    expect(find.text('Cache report'), findsOneWidget);
  });
}
