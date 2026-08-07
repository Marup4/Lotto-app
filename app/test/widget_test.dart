import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/ui/draw_tab.dart';

Draw draw(int round) => Draw(
      round: round,
      date: DateTime(2026, 8, 1),
      numbers: const [6, 7, 11, 15, 39, 43],
      bonus: 20,
      firstWinners: 9,
      firstAmount: 3090961625,
      totalSales: 115445069000,
      winAuto: 7,
      winManual: 2,
      winSemi: 0,
    );

Future<void> pumpTab(WidgetTester tester, List<Draw> draws) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: DrawTab(draws: draws))));

/// 회차 선택기도 회차 라벨을 갖고 있으므로, 본문에 보이는 것만 센다.
Finder onPage(String text) =>
    find.descendant(of: find.byType(PageView), matching: find.text(text));

void main() {
  testWidgets('열면 최신 회차가 먼저 보인다', (tester) async {
    // 로그인도 온보딩도 없이 최신 회차가 즉시 보이는 것이 이 앱의 핵심이다
    await pumpTab(tester, [draw(1233), draw(1234), draw(1235)]);

    // 회차 번호는 선택기가 표시하고, 본문은 그 회차의 추첨일을 보여준다
    expect(tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>)).value, 1235);
    expect(onPage('2026.08.01 추첨'), findsOneWidget);
  });

  testWidgets('당첨번호 6개와 보너스를 모두 보여준다', (tester) async {
    await pumpTab(tester, [draw(1235)]);

    for (final n in [6, 7, 11, 15, 39, 43, 20]) {
      expect(onPage('$n'), findsOneWidget);
    }
    expect(onPage('+'), findsOneWidget);
  });

  testWidgets('금액은 줄여 쓴 형태로 나온다', (tester) async {
    await pumpTab(tester, [draw(1235)]);

    expect(onPage('30억 9,096만원'), findsOneWidget);
    expect(onPage('1,154억 4,506만원'), findsOneWidget);
  });

  testWidgets('자동수동 값이 없는 옛 회차는 그 줄을 감춘다', (tester) async {
    // 261회차 이하는 원본에 값이 없다. 0/0/0을 보여주면 오해를 준다.
    final old = Draw(
      round: 100,
      date: DateTime(2004, 1, 1),
      numbers: const [1, 2, 3, 4, 5, 6],
      bonus: 7,
      firstWinners: 4,
      firstAmount: 1000000000,
      totalSales: 10000000000,
      winAuto: 0,
      winManual: 0,
      winSemi: 0,
    );

    await pumpTab(tester, [old]);

    expect(onPage('자동/수동/반자동'), findsNothing);
    expect(onPage('1등 당첨자'), findsOneWidget);
  });
}
