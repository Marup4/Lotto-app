import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/ui/stats_tab.dart';

Draw draw(int round, List<int> numbers,
        {int auto = 0, int manual = 0, int semi = 0}) =>
    Draw(
      round: round,
      date: DateTime(2026, 1, 1),
      numbers: numbers,
      bonus: 45,
      firstWinners: auto + manual + semi,
      firstAmount: 1,
      totalSales: 1,
      winAuto: auto,
      winManual: manual,
      winSemi: semi,
    );

/// 번호 하나만 계속 바뀌는 60회차. 빈도·미출현이 모두 뚜렷하게 갈린다.
List<Draw> series({int count = 60}) => [
      for (var i = 0; i < count; i++)
        draw(1000 + i, [1, 2, 3, 4, 5, 6 + (i % 10)],
            auto: 2, manual: 1, semi: 0)
    ];

/// 통계 탭은 세로로 길다. 기본 테스트 화면(800px)에서는 아래 항목이
/// 아예 빌드되지 않아 찾을 수 없으므로, 전체가 한 화면에 들어오게 키운다.
Future<void> pump(WidgetTester tester, List<Draw> draws) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: StatsTab(draws: draws))));
}

void main() {
  testWidgets('세 항목이 모두 나온다', (tester) async {
    await pump(tester, series());

    expect(find.text('많이 나온 번호'), findsOneWidget);
    expect(find.text('오래 안 나온 번호'), findsOneWidget);
    expect(find.text('1등은 어떻게 샀을까'), findsOneWidget);
  });

  testWidgets('전체 누적 빈도는 보여주지 않는다', (tester) async {
    // 1235회를 누적하면 45개가 전부 평균 근처로 수렴해 의미가 없다.
    // 사용자와 합의해 뺀 항목이므로 되살아나면 테스트가 잡는다.
    await pump(tester, series());

    expect(find.textContaining('전체'), findsNothing);
  });

  testWidgets('구간을 바꾸면 수치가 따라 바뀐다', (tester) async {
    await pump(tester, series());

    // 표본에 쓰이는 번호는 1~5와 6~15, 모두 15개다 → 나머지 30개가 안 나온다
    expect(find.text('최근 30회차에 나오지 않은 번호 30개'), findsOneWidget);

    await tester.tap(find.text('최근 10회'));
    await tester.pumpAndSettle();

    expect(find.text('최근 10회차에 나오지 않은 번호 30개'), findsOneWidget);
    // 1~5번은 매 회차 나오므로 10회 구간에서 10회다
    expect(find.text('10회'), findsWidgets);
  });

  testWidgets('미출현은 오래된 순으로 최대 10개만 나온다', (tester) async {
    await pump(tester, series());

    // 7~15번만 돌아가며 나오고 나머지 30개는 한 번도 안 나온다.
    // 한 번도 안 나온 번호는 보유 회차 수(60)로 표시된다.
    expect(find.text('60회차'), findsNWidgets(10));
  });

  testWidgets('자동/수동 비율을 백분율과 건수로 보여준다', (tester) async {
    await pump(tester, series());

    expect(find.text('최근 60회차 1등 180건 기준입니다.'), findsOneWidget);
    expect(find.text('66.7% (120건)'), findsOneWidget); // 자동
    expect(find.text('33.3% (60건)'), findsOneWidget); // 수동
    expect(find.text('0.0% (0건)'), findsOneWidget); // 반자동
  });

  testWidgets('구매 방식 자료가 없는 옛 회차만 있으면 그렇게 말한다', (tester) async {
    // 261회차 이하는 원본에 구분이 없다. 0으로 나누면 NaN%가 나온다.
    await pump(tester, [draw(100, [1, 2, 3, 4, 5, 6])]);

    expect(find.text('이 구간에는 구매 방식 자료가 없습니다.'), findsOneWidget);
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('당첨 확률과 무관하다는 안내가 항상 있다', (tester) async {
    // 설계 문서 §7 F3·§12. 심사 대응이자 정직성 문제다.
    await pump(tester, series());

    expect(find.textContaining('당첨 확률은 같습니다'), findsOneWidget);
  });
}
