import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/ui/format.dart';

void main() {
  group('금액 표기', () {
    test('억 단위는 억과 만으로 끊어 읽는다', () {
      // 원 단위로 다 보여주면 자릿수를 세게 된다
      expect(formatWon(1854965425), '18억 5,496만원');
    });

    test('만 단위가 0이면 억만 남긴다', () {
      expect(formatWon(300000000), '3억원');
    });

    test('조 단위도 억으로만 표기한다', () {
      // 총 판매금액은 1,154억원대다
      expect(formatWon(115445069000), '1,154억 4,506만원');
    });

    test('억 미만은 만 단위로 끊는다', () {
      expect(formatWon(50000), '5만원');
    });

    test('만 미만은 그대로 원으로 쓴다', () {
      expect(formatWon(5000), '5,000원');
    });

    test('0원도 표기할 수 있다', () {
      expect(formatWon(0), '0원');
    });
  });
}
