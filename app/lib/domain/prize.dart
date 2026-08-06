/// 등수 판정 (설계 문서 §7 F2).
///
/// 앱 신뢰도가 걸린 지점이다. 여기가 틀리면 앱 전체를 믿을 수 없다.
/// 순수 함수로 두고 유닛 테스트로 못 박는다.
enum Rank { first, second, third, fourth, fifth, none }

Rank judgeRank({
  required List<int> mine,
  required List<int> winning,
  required int bonus,
}) {
  // 교집합 크기로 판정한다. 입력 순서는 무관하다.
  final matched = mine.toSet().intersection(winning.toSet()).length;

  switch (matched) {
    case 6:
      return Rank.first;
    case 5:
      // 2등과 3등을 가르는 유일한 조건. 여기가 이 함수에서 가장 위험한 줄이다.
      return mine.contains(bonus) ? Rank.second : Rank.third;
    case 4:
      return Rank.fourth;
    case 3:
      return Rank.fifth;
    default:
      return Rank.none;
  }
}
