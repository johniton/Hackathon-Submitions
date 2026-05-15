
import 'package:flutter_test/flutter_test.dart';

import 'package:hustlr/main.dart';

void main() {
  testWidgets('SkillMap app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SkillMapApp());

    // Verify that our app loads with the Skeleton Navigation Page
    expect(find.text('SkillMap Skeleton Navigation'), findsOneWidget);
  });
}
