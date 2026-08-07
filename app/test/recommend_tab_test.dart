import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/data/my_numbers_repository.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/ui/ball.dart';
import 'package:lotto_app/ui/recommend_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Draw draw(int round) => Draw(
      round: round,
      date: DateTime(2026, 8, 1),
      numbers: const [6, 7, 11, 15, 39, 43],
      bonus: 20,
      firstWinners: 9,
      firstAmount: 1,
      totalSales: 1,
      winAuto: 1,
      winManual: 0,
      winSemi: 0,
    );

Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendTab(draws: [for (var r = 1200; r <= 1235; r++) draw(r)]),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('뽑기를 누르면 번호 여섯 개가 나온다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('번호 뽑기'));
    await tester.pumpAndSettle();

    expect(find.byType(Ball), findsNWidgets(6));
  });

  testWidgets('다시 뽑으면 결과가 갱신된다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('번호 뽑기'));
    await tester.pumpAndSettle();
    final first =
        tester.widgetList<Ball>(find.byType(Ball)).map((b) => b.number).toList();

    // 무작위라 같은 값이 다시 나올 수도 있어 여러 번 시도한다
    var changed = false;
    for (var i = 0; i < 10 && !changed; i++) {
      await tester.tap(find.text('번호 뽑기'));
      await tester.pumpAndSettle();
      final next = tester
          .widgetList<Ball>(find.byType(Ball))
          .map((b) => b.number)
          .toList();
      changed = !const ListEquality().equals(first, next);
    }

    expect(changed, isTrue, reason: '열 번을 뽑았는데 결과가 한 번도 안 바뀌었다');
  });

  testWidgets('결과를 내 번호로 저장할 수 있다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('번호 뽑기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 번호에 저장'));
    await tester.pumpAndSettle();

    expect(find.text('내 번호에 저장됨'), findsOneWidget);
    expect((await MyNumbersRepository().loadAll()).length, 1);
  });

  group('설계 문서 §7 F3 — 금지 표현', () {
    testWidgets('예측·확률 관련 표현을 쓰지 않는다', (tester) async {
      await pump(tester);

      // 심사 대응이자 정직성 문제다. 문구가 슬그머니 바뀌는 것을 막는다.
      for (final banned in ['예측', '확률이 높', '당첨 확률을 높', '적중']) {
        expect(find.textContaining(banned), findsNothing,
            reason: '금지 표현이 화면에 있다: $banned');
      }
    });

    testWidgets('통계와 당첨 확률이 무관하다는 안내를 고정 노출한다', (tester) async {
      await pump(tester);

      expect(find.textContaining('관계가 없습니다'), findsOneWidget);
      expect(find.textContaining('당첨 확률은 같습니다'), findsOneWidget);
    });

    testWidgets('가중 모드 이름은 사실 서술이다', (tester) async {
      await pump(tester);

      expect(find.textContaining('많이 나온 번호로'), findsOneWidget);
      expect(find.textContaining('적게 나온 번호로'), findsOneWidget);
    });
  });
}

/// 리스트 비교용 최소 구현 (collection 패키지를 끌어오지 않는다).
class ListEquality {
  const ListEquality();

  bool equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
