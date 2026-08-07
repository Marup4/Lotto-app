import 'draw.dart';
import 'prize.dart';

/// 저장한 번호 한 세트를 특정 회차와 대조한 결과.
///
/// 등수만 보여주면 "왜 이 등수인지"가 안 보인다. 어떤 번호가 맞았는지
/// 함께 돌려줘 화면에서 강조할 수 있게 한다.
class MatchResult {
  const MatchResult({
    required this.rank,
    required this.matched,
    required this.hasBonus,
  });

  final Rank rank;

  /// 당첨번호 6개 중 맞은 것 (오름차순). 보너스는 포함하지 않는다 —
  /// 등수 조건에서 역할이 다르기 때문이다.
  final List<int> matched;

  final bool hasBonus;

  factory MatchResult.of({required List<int> mine, required Draw draw}) {
    final matched = mine.where(draw.numbers.contains).toList()..sort();
    return MatchResult(
      rank: judgeRank(mine: mine, winning: draw.numbers, bonus: draw.bonus),
      matched: matched,
      hasBonus: mine.contains(draw.bonus),
    );
  }
}

String rankLabel(Rank rank) => switch (rank) {
      Rank.first => '1등',
      Rank.second => '2등',
      Rank.third => '3등',
      Rank.fourth => '4등',
      Rank.fifth => '5등',
      Rank.none => '미당첨',
    };
