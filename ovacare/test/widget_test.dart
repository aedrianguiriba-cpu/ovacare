import 'package:flutter_test/flutter_test.dart';

import 'package:ovacare/main.dart';

void main() {
  testWidgets('OvaCare app loads login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OvaCareApp());

    // Verify login screen is shown
    expect(find.text('OvaCare - PCOS Health Companion'), findsOneWidget);
  });
}
