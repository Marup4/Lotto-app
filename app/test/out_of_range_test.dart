import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/ui/ticket_check_page.dart';

Draw draw(int round) => Draw(
      round: round,
      date: DateTime(2026, 8, 1),
      numbers: const [1, 2, 3, 4, 5, 6],
      bonus: 7,
      firstWinners: 1,
      firstAmount: 1,
      totalSales: 1,
      winAuto: 1,
      winManual: 0,
      winSemi: 0,
    );

// 앱은 최근 100회차만 담는다 (설계 문서 §13-3)
final bundled = [for (var r = 1136; r <= 1235; r++) draw(r)];

void main() {
  test('오래된 용지는 지급 기한이 지났다는 것을 알려준다', () {
    // 그냥 "없는 회차"라고만 하면 고장으로 보인다.
    // 1년(약 52회차)이 지나면 수령 자체가 불가능하다는 게 진짜 정보다.
    final message = outOfRangeMessage(1122, bundled);

    expect(message, contains('1122'));
    expect(message, contains('지급 기한'));
  });

  test('아직 자료가 없는 최신 용지는 다르게 안내한다', () {
    // 추첨 전이거나 데이터 갱신 전이다. 기한 이야기를 하면 틀린 말이 된다.
    final message = outOfRangeMessage(1240, bundled);

    expect(message, contains('1240'));
    expect(message, isNot(contains('지급 기한')));
  });

  test('확인 가능한 범위는 회차 번호가 아니라 개수로 알려준다', () {
    // 사용자에게 "1136~1235회"는 외울 수도 가늠할 수도 없는 숫자다.
    // "최근 100회차"가 훨씬 직관적이다.
    final message = outOfRangeMessage(1122, bundled);

    expect(message, contains('최근 100회차'));
    expect(message, isNot(contains('1136')));
  });
}
