import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/domain/match_result.dart';
import 'package:lotto_app/domain/prize.dart';

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

void main() {
  test('맞은 번호를 그대로 알려준다', () {
    final r = MatchResult.of(mine: const [6, 7, 11, 1, 2, 3], draw: draw);

    expect(r.matched, [6, 7, 11]);
    expect(r.rank, Rank.fifth);
    expect(r.hasBonus, isFalse);
  });

  test('보너스를 맞췄으면 따로 표시한다', () {
    final r = MatchResult.of(mine: const [6, 7, 11, 15, 39, 20], draw: draw);

    expect(r.rank, Rank.second);
    expect(r.hasBonus, isTrue);
    // 보너스는 '맞은 번호'에 섞지 않는다 — 등수 조건이 다르기 때문이다
    expect(r.matched, [6, 7, 11, 15, 39]);
  });

  test('미당첨도 맞은 개수는 보여준다', () {
    final r = MatchResult.of(mine: const [6, 7, 1, 2, 3, 4], draw: draw);

    expect(r.rank, Rank.none);
    expect(r.matched, [6, 7]);
  });

  group('등수 표기', () {
    test('당첨은 등수로 쓴다', () {
      expect(rankLabel(Rank.first), '1등');
      expect(rankLabel(Rank.fifth), '5등');
    });

    test('미당첨은 낙첨으로 쓴다', () {
      expect(rankLabel(Rank.none), '미당첨');
    });
  });
}
