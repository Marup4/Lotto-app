import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/data/my_numbers_repository.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/domain/my_numbers.dart';
import 'package:lotto_app/ui/my_numbers_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(home: MyNumbersTab(draws: [draw(1234), draw(1235)])),
    );

Future<void> save(List<int> numbers, {String label = 'A'}) =>
    MyNumbersRepository().add(MyNumbers(
      id: label,
      numbers: numbers,
      label: label,
      createdAt: DateTime.utc(2026, 8, 1),
    ));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('저장한 번호가 없으면 안내를 보여준다', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('저장한 번호가 없습니다'), findsOneWidget);
  });

  testWidgets('저장한 번호를 최신 회차에 대조해 등수를 보여준다', (tester) async {
    await save(const [6, 7, 11, 15, 39, 43]);   // 6개 일치

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('1등'), findsOneWidget);
    expect(find.text('6개 일치'), findsOneWidget);
  });

  testWidgets('보너스를 맞춘 2등을 구분해 표시한다', (tester) async {
    // 2등/3등 경계는 앱 신뢰도가 걸린 지점이다 (설계 문서 §7 F2)
    await save(const [6, 7, 11, 15, 39, 20]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('2등'), findsOneWidget);
    expect(find.text('5개 일치 + 보너스'), findsOneWidget);
  });

  testWidgets('미당첨도 몇 개 맞았는지 알려준다', (tester) async {
    await save(const [6, 7, 1, 2, 3, 4]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('미당첨'), findsOneWidget);
    expect(find.text('2개 일치'), findsOneWidget);
  });

  testWidgets('대조 회차를 바꾸면 판정이 다시 된다', (tester) async {
    await save(const [6, 7, 11, 15, 39, 43]);

    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('1등'), findsOneWidget);

    // 1234회는 당첨번호가 같게 만들어 뒀으므로 결과도 같아야 한다
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1234회').last);
    await tester.pumpAndSettle();

    expect(find.text('1등'), findsOneWidget);
  });

  testWidgets('번호를 지우면 목록에서 사라진다', (tester) async {
    await save(const [1, 2, 3, 4, 5, 6]);

    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('저장한 번호가 없습니다'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('저장한 번호가 없습니다'), findsOneWidget);
  });

  testWidgets('번호를 여섯 개 고르기 전에는 저장할 수 없다', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('번호 추가'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    for (final n in [1, 2, 3, 4, 5]) {
      await tester.tap(find.text('$n'));
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    await tester.tap(find.text('6'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
}
