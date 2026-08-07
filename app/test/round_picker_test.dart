import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/ui/draw_tab.dart';

// 설계 문서 §7 F1: "좌우 스와이프 / 회차 직접 입력으로 이동".
// 스와이프만으로는 과거 회차에 닿기까지 너무 많이 넘겨야 한다.

Draw draw(int round) => Draw(
      round: round,
      date: DateTime(2026, 8, 1).subtract(Duration(days: 7 * (1235 - round))),
      numbers: const [6, 7, 11, 15, 39, 43],
      bonus: 20,
      firstWinners: 9,
      firstAmount: 3090961625,
      totalSales: 115445069000,
      winAuto: 7,
      winManual: 2,
      winSemi: 0,
    );

List<Draw> draws(int count) =>
    [for (var r = 1235 - count + 1; r <= 1235; r++) draw(r)];

Future<void> pump(WidgetTester tester, List<Draw> list) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: DrawTab(draws: list))));

void main() {
  testWidgets('회차 선택기가 최신 회차를 가리킨 채로 시작한다', (tester) async {
    await pump(tester, draws(100));

    expect(tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>)).value, 1235);
  });

  testWidgets('선택기에서 회차를 고르면 그 회차가 표시된다', (tester) async {
    await pump(tester, draws(100));

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    // 메뉴가 열리면 같은 라벨이 둘 이상 생기므로 마지막 것을 누른다
    await tester.tap(find.text('1230회').last);
    await tester.pumpAndSettle();

    expect(find.text('2026.06.27 추첨'), findsOneWidget);
  });

  testWidgets('선택기 항목은 최신 회차부터 나열된다', (tester) async {
    await pump(tester, draws(5));

    final picker =
        tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>));

    expect(picker.items!.map((i) => i.value).toList(),
        [1235, 1234, 1233, 1232, 1231]);
  });

  testWidgets('스와이프로 넘겨도 선택기가 따라온다', (tester) async {
    await pump(tester, draws(10));

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>)).value, 1234);
  });
}
