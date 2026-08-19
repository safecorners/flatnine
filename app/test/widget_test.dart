import 'package:flutter_test/flutter_test.dart';

import 'package:roadsense/main.dart';

void main() {
  testWidgets('측정 화면이 뜨고 시작 버튼이 보인다', (tester) async {
    await tester.pumpWidget(const FlatnineApp());
    expect(find.text('측정 시작'), findsOneWidget);
    expect(find.text('노면 측정'), findsOneWidget);
  });
}
