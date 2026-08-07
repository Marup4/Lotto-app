import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/domain/ticket.dart';
import 'package:lotto_app/ui/ticket_check_page.dart';

final draw = Draw(
  round: 1235,
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

Future<void> pumpCard(WidgetTester tester, Ticket ticket) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TicketCard(ticket: ticket, draw: draw, index: 1),
          ),
        ),
      ),
    );

void main() {
  testWidgets('한 장의 모든 게임을 한 화면에 보여준다', (tester) async {
    await pumpCard(
      tester,
      Ticket(round: 1235, games: const [
        [6, 7, 11, 15, 39, 43], // 1등
        [1, 2, 3, 4, 5, 8], // 미당첨
        [6, 7, 11, 1, 2, 3], // 5등
      ]),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('1등'), findsWidgets);
    expect(find.text('5등'), findsOneWidget);
  });

  testWidgets('가장 높은 등수와 당첨 게임 수를 요약한다', (tester) async {
    await pumpCard(
      tester,
      Ticket(round: 1235, games: const [
        [6, 7, 11, 1, 2, 3], // 5등
        [6, 7, 11, 15, 1, 2], // 4등
        [1, 2, 3, 4, 5, 8], // 미당첨
      ]),
    );

    expect(find.text('4등 2게임'), findsOneWidget);
  });

  testWidgets('전부 미당첨이면 미당첨으로 요약한다', (tester) async {
    await pumpCard(
      tester,
      Ticket(round: 1235, games: const [
        [1, 2, 3, 4, 5, 8],
      ]),
    );

    expect(find.text('미당첨'), findsWidgets);
  });

  testWidgets('높은 등수에는 공식 확인 안내를 띄운다', (tester) async {
    // 당첨 여부를 우리가 단정할 자리가 아니다. 수령은 공식 절차다.
    await pumpCard(
      tester,
      Ticket(round: 1235, games: const [
        [6, 7, 11, 15, 39, 43], // 1등
      ]),
    );

    expect(find.textContaining('공식 확인'), findsOneWidget);
  });

  testWidgets('낮은 등수에는 안내를 띄우지 않는다', (tester) async {
    await pumpCard(
      tester,
      Ticket(round: 1235, games: const [
        [6, 7, 11, 1, 2, 3], // 5등
      ]),
    );

    expect(find.textContaining('공식 확인'), findsNothing);
  });
}
