import 'package:flutter_test/flutter_test.dart';

import 'package:dongxin_flutter/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const DongxinApp());
    expect(find.text('懂心 · 消灭不开心'), findsOneWidget);
  });
}
