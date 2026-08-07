import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/domain/prize.dart';
import 'package:lotto_app/domain/ticket.dart';

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

// 실물 용지에서 읽은 QR (1234회, 2026-08-07 확보).
//   v = 회차4자리 + (마커1자 + 번호12자리) × 게임수 + 꼬리18자리
const realQr =
    'http://qr.dhlottery.co.kr/?v=1234q020709131430q050820222526'
    'q020416202332q021217182124q011617242935187712019714800177';

void main() {
  group('QR 읽기', () {
    test('실물 QR에서 회차와 다섯 게임을 뽑아낸다', () {
      final t = Ticket.fromQr(realQr)!;

      expect(t.round, 1234);
      expect(t.games, [
        [2, 7, 9, 13, 14, 30],
        [5, 8, 20, 22, 25, 26],
        [2, 4, 16, 20, 23, 32],
        [2, 12, 17, 18, 21, 24],
        [1, 16, 17, 24, 29, 35],
      ]);
    });

    test('꼬리의 일련번호는 게임으로 오해하지 않는다', () {
      // 꼬리 18자리를 숫자로만 잘라 읽으면 없는 게임이 생긴다
      expect(Ticket.fromQr(realQr)!.games.length, 5);
    });

    test('게임이 하나뿐인 용지도 읽는다', () {
      final t = Ticket.fromQr(
          'http://qr.dhlottery.co.kr/?v=1200q010203040506187712019714800177')!;

      expect(t.round, 1200);
      expect(t.games, [
        [1, 2, 3, 4, 5, 6]
      ]);
    });

    test('로또 QR이 아니면 읽지 않는다', () {
      expect(Ticket.fromQr('https://example.com'), isNull);
      expect(Ticket.fromQr('그냥 문자열'), isNull);
      expect(Ticket.fromQr(''), isNull);
    });

    test('번호가 로또 범위를 벗어나면 읽지 않는다', () {
      // 46은 존재할 수 없다. 엉뚱한 QR을 억지로 해석하지 않는다.
      expect(
          Ticket.fromQr('http://qr.dhlottery.co.kr/?v=1200q010203040546000000'),
          isNull);
    });

    test('게임이 하나도 없으면 읽지 않는다', () {
      expect(Ticket.fromQr('http://qr.dhlottery.co.kr/?v=1234'), isNull);
    });
  });

  group('티켓', () {
    test('게임마다 라벨이 A부터 붙는다', () {
      final t = Ticket(games: const [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10, 11, 12],
      ]);

      expect(t.labels, ['A', 'B']);
    });

    test('게임 번호는 오름차순으로 보관한다', () {
      final t = Ticket(games: const [
        [43, 6, 39, 7, 15, 11],
      ]);

      expect(t.games.single, [6, 7, 11, 15, 39, 43]);
    });
  });

  group('한 장 통째로 대조', () {
    test('게임 수만큼 결과가 순서대로 나온다', () {
      final t = Ticket(games: const [
        [6, 7, 11, 15, 39, 43], // 1등
        [1, 2, 3, 4, 5, 8], // 미당첨
      ]);

      final results = t.check(draw);

      expect(results.length, 2);
      expect(results[0].rank, Rank.first);
      expect(results[1].rank, Rank.none);
    });

    test('가장 높은 등수를 요약으로 알려준다', () {
      final t = Ticket(games: const [
        [1, 2, 3, 4, 5, 8], // 미당첨
        [6, 7, 11, 1, 2, 3], // 5등
        [6, 7, 11, 15, 1, 2], // 4등
      ]);

      expect(t.bestRank(draw), Rank.fourth);
    });

    test('전부 미당첨이면 요약도 미당첨이다', () {
      final t = Ticket(games: const [
        [1, 2, 3, 4, 5, 8],
        [1, 2, 3, 4, 5, 9],
      ]);

      expect(t.bestRank(draw), Rank.none);
    });

    test('당첨된 게임이 몇 개인지 센다', () {
      final t = Ticket(games: const [
        [6, 7, 11, 1, 2, 3], // 5등
        [6, 7, 11, 15, 1, 2], // 4등
        [1, 2, 3, 4, 5, 8], // 미당첨
      ]);

      expect(t.winningCount(draw), 2);
    });
  });
}
