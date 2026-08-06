import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/prize.dart';

// 설계 문서 §7 F2. 2등/3등 경계 버그는 치명적이므로 경계를 집중적으로 덮는다.
//
//   1등  6개 일치
//   2등  5개 일치 + 보너스
//   3등  5개 일치
//   4등  4개 일치
//   5등  3개 일치

const winning = [1, 2, 3, 4, 5, 6];
const bonus = 7;

Rank judge(List<int> mine) =>
    judgeRank(mine: mine, winning: winning, bonus: bonus);

void main() {
  test('여섯 개가 모두 맞으면 1등', () {
    expect(judge([1, 2, 3, 4, 5, 6]), Rank.first);
  });

  test('다섯 개 일치에 보너스까지 맞으면 2등', () {
    expect(judge([1, 2, 3, 4, 5, 7]), Rank.second);
  });

  test('다섯 개만 맞고 보너스가 아니면 3등', () {
    // 2등과의 유일한 차이는 여섯 번째 번호가 보너스인지 여부다
    expect(judge([1, 2, 3, 4, 5, 8]), Rank.third);
  });

  test('보너스를 갖고 있어도 네 개만 맞으면 4등', () {
    // 보너스는 5개 일치일 때만 의미가 있다. 4등에는 영향을 주지 않는다.
    expect(judge([1, 2, 3, 4, 7, 9]), Rank.fourth);
  });

  test('세 개가 맞으면 5등', () {
    expect(judge([1, 2, 3, 8, 9, 10]), Rank.fifth);
  });

  test('두 개만 맞으면 미당첨', () {
    expect(judge([1, 2, 8, 9, 10, 11]), Rank.none);
  });

  test('하나도 안 맞으면 미당첨', () {
    expect(judge([8, 9, 10, 11, 12, 13]), Rank.none);
  });

  test('두 개 일치에 보너스가 있어도 미당첨', () {
    expect(judge([1, 2, 7, 9, 10, 11]), Rank.none);
  });

  test('번호 순서가 뒤섞여 있어도 결과가 같다', () {
    expect(judge([6, 5, 4, 3, 2, 1]), Rank.first);
    expect(judge([7, 5, 1, 3, 2, 4]), Rank.second);
  });

  test('당첨번호도 정렬돼 있지 않을 수 있다', () {
    expect(
      judgeRank(mine: [1, 2, 3, 4, 5, 6], winning: [6, 3, 1, 5, 2, 4], bonus: 7),
      Rank.first,
    );
  });
}
