import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/recommender.dart';

/// 씨앗을 고정해 결과를 재현 가능하게 만든다.
List<int> pick({
  PickMode mode = PickMode.random,
  Set<int> excluded = const {},
  Set<int> fixed = const {},
  Map<int, int> frequency = const {},
  int seed = 42,
}) =>
    recommend(
      mode: mode,
      excluded: excluded,
      fixed: fixed,
      frequency: frequency,
      random: Random(seed),
    );

void main() {
  group('기본 규칙', () {
    test('항상 서로 다른 여섯 개를 오름차순으로 낸다', () {
      for (var seed = 0; seed < 50; seed++) {
        final n = pick(seed: seed);

        expect(n.length, 6);
        expect(n.toSet().length, 6, reason: '중복이 있다: $n');
        expect(n, [...n]..sort(), reason: '정렬되지 않았다: $n');
      }
    });

    test('1~45 범위를 벗어나지 않는다', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(pick(seed: seed).every((v) => v >= 1 && v <= 45), isTrue);
      }
    });

    test('씨앗이 같으면 같은 결과가 나온다', () {
      expect(pick(seed: 7), pick(seed: 7));
    });
  });

  group('제외 번호', () {
    test('제외한 번호는 절대 나오지 않는다', () {
      const excluded = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

      for (var seed = 0; seed < 50; seed++) {
        final n = pick(excluded: excluded, seed: seed);

        expect(n.toSet().intersection(excluded), isEmpty, reason: '$n');
      }
    });

    test('39개를 제외해도 남은 여섯 개로 채운다', () {
      final excluded = {for (var i = 7; i <= 45; i++) i};

      expect(pick(excluded: excluded), [1, 2, 3, 4, 5, 6]);
    });
  });

  group('고정 번호', () {
    test('고정한 번호는 반드시 포함된다', () {
      const fixed = {7, 14, 21};

      for (var seed = 0; seed < 30; seed++) {
        final n = pick(fixed: fixed, seed: seed);

        expect(n.toSet().containsAll(fixed), isTrue, reason: '$n');
        expect(n.length, 6);
      }
    });

    test('여섯 개를 다 고정하면 그대로 나온다', () {
      expect(pick(fixed: const {3, 1, 2, 6, 5, 4}), [1, 2, 3, 4, 5, 6]);
    });

    test('고정 번호는 제외 번호보다 우선한다', () {
      // 사용자가 방금 고른 것이 더 최근 의사표시다
      final n = pick(fixed: const {13}, excluded: const {13});

      expect(n, contains(13));
    });
  });

  group('빈도 가중', () {
    // 100회차쯤의 실제 분포를 흉내낸다. 번호당 평균 13회 남짓이고
    // 많아야 22회, 적으면 5회 정도다.
    final frequency = {
      for (var i = 1; i <= 45; i++) i: i <= 6 ? 22 : (i >= 40 ? 5 : 13)
    };

    /// 200번 뽑아 [target]에 속한 번호가 평균 몇 개 나오는지.
    double average(PickMode mode, bool Function(int) target) {
      var hits = 0;
      for (var seed = 0; seed < 200; seed++) {
        hits += pick(mode: mode, frequency: frequency, seed: seed)
            .where(target)
            .length;
      }
      return hits / 200;
    }

    test('많이 나온 번호 가중은 균등보다 그쪽을 더 자주 고른다', () {
      // 절대값이 아니라 균등 대비로 본다. 가중 공식을 손봐도
      // 의도가 살아 있는 한 이 테스트는 유효하다.
      final hot = average(PickMode.hot, (v) => v <= 6);
      final baseline = average(PickMode.random, (v) => v <= 6);

      expect(hot, greaterThan(baseline * 1.3),
          reason: '가중 $hot vs 균등 $baseline');
    });

    test('적게 나온 번호 가중은 균등보다 그쪽을 더 자주 고른다', () {
      final cold = average(PickMode.cold, (v) => v >= 40);
      final baseline = average(PickMode.random, (v) => v >= 40);

      expect(cold, greaterThan(baseline * 1.3),
          reason: '가중 $cold vs 균등 $baseline');
    });

    test('두 가중은 서로 반대 방향으로 치우친다', () {
      expect(average(PickMode.hot, (v) => v <= 6),
          greaterThan(average(PickMode.cold, (v) => v <= 6)));
    });

    test('빈도 자료가 없으면 완전 랜덤과 같이 동작한다', () {
      // 데이터가 없다고 죽지 않는다
      final n = pick(mode: PickMode.hot, frequency: const {});

      expect(n.length, 6);
      expect(n.toSet().length, 6);
    });

    test('가중 모드에서도 제외와 고정을 지킨다', () {
      final n = pick(
        mode: PickMode.hot,
        frequency: frequency,
        fixed: const {45},
        excluded: const {1, 2, 3},
      );

      expect(n, contains(45));
      expect(n.toSet().intersection({1, 2, 3}), isEmpty);
    });
  });

  group('만들 수 없는 조건', () {
    test('남은 번호가 여섯 개에 못 미치면 만들지 않는다', () {
      final excluded = {for (var i = 6; i <= 45; i++) i};

      expect(() => pick(excluded: excluded), throwsArgumentError);
    });

    test('고정 번호가 여섯 개를 넘으면 만들지 않는다', () {
      expect(() => pick(fixed: const {1, 2, 3, 4, 5, 6, 7}),
          throwsArgumentError);
    });
  });
}
