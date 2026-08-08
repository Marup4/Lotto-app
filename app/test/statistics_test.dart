import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';
import 'package:lotto_app/domain/statistics.dart';

/// 통계는 당첨번호와 자동/수동 건수만 쓴다. 나머지 필드는 채워도 의미가 없다.
Draw draw(int round, List<int> numbers,
        {int bonus = 45, int auto = 0, int manual = 0, int semi = 0}) =>
    Draw(
      round: round,
      date: DateTime(2026, 1, 1),
      numbers: numbers,
      bonus: bonus,
      firstWinners: auto + manual + semi,
      firstAmount: 1,
      totalSales: 1,
      winAuto: auto,
      winManual: manual,
      winSemi: semi,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('실제 번들 데이터', () {
    // 앱이 100회차만 갖고 계산해도 배치가 전 회차로 낸 값과 같아야 한다.
    // 이게 깨지면 stats.json을 따로 내려받아야 한다는 신호다.
    //
    // 기대값을 적어두지 않는다. 배치가 매주 데이터를 갱신하므로 숫자를
    // 박아두면 추첨 때마다 테스트가 깨진다 — 실제로 1236회차에서 깨졌다.
    // 대신 배치의 산출물(data/stats.json)과 직접 대조한다.
    Future<List<Draw>> bundle() async {
      final raw = await rootBundle.loadString('assets/data/draws.json');
      return [
        for (final j in jsonDecode(raw) as List)
          Draw.fromJson(j as Map<String, dynamic>)
      ];
    }

    /// 배치가 전 회차로 계산해둔 미출현 기간. 테스트는 저장소 안에서 도므로
    /// 앱 에셋이 아닌 원본 파일을 직접 읽는다.
    Map<int, int> batchDroughts() {
      final raw = File('../data/stats.json').readAsStringSync();
      final map = (jsonDecode(raw) as Map<String, dynamic>)['drought'] as Map;
      return {
        for (final e in map.entries) int.parse(e.key as String): e.value as int
      };
    }

    test('미출현 기간이 전 회차 계산과 45개 전부 일치한다', () async {
      final mine = {for (final d in droughts(await bundle())) d.number: d.gap};

      expect(mine, batchDroughts());
    });

    test('번들만으로도 미출현이 창 밖으로 나가지 않는다', () async {
      final draws = await bundle();

      // 창을 벗어난 번호가 있으면 gap이 보유 회차 수와 같아진다
      expect(droughts(draws).first.gap, lessThan(draws.length));
    });
  });

  group('출현 빈도', () {
    test('번호가 나온 횟수를 센다', () {
      final draws = [
        draw(1, [1, 2, 3, 4, 5, 6]),
        draw(2, [1, 2, 3, 7, 8, 9]),
      ];

      final f = frequency(draws);

      expect(f[1], 2);
      expect(f[7], 1);
    });

    test('한 번도 안 나온 번호는 0으로 채운다', () {
      // 화면이 45개를 모두 그려야 하므로 결측이 있으면 안 된다
      final f = frequency([draw(1, [1, 2, 3, 4, 5, 6])]);

      expect(f.length, 45);
      expect(f[45], 0);
    });

    test('recent를 주면 최근 N회차만 센다', () {
      final draws = [
        draw(1, [1, 2, 3, 4, 5, 6]),
        draw(2, [7, 8, 9, 10, 11, 12]),
        draw(3, [7, 8, 9, 13, 14, 15]),
      ];

      final f = frequency(draws, recent: 2);

      expect(f[1], 0, reason: '1회차는 창 밖이다');
      expect(f[7], 2);
    });

    test('recent가 보유 회차보다 크면 전부 센다', () {
      final f = frequency([draw(1, [1, 2, 3, 4, 5, 6])], recent: 50);

      expect(f[1], 1);
    });

    test('보너스 번호는 세지 않는다', () {
      // 1등 기준 통계다. 보너스를 섞으면 2등 얘기가 되어 의미가 흐려진다
      final f = frequency([draw(1, [1, 2, 3, 4, 5, 6], bonus: 45)]);

      expect(f[45], 0);
    });
  });

  group('미출현 기간', () {
    test('마지막 출현 이후 지난 회차 수를 센다', () {
      final draws = [
        draw(1, [1, 2, 3, 4, 5, 6]),
        draw(2, [7, 8, 9, 10, 11, 12]),
        draw(3, [7, 8, 9, 13, 14, 15]),
      ];

      final gaps = {for (final d in droughts(draws)) d.number: d.gap};

      expect(gaps[7], 0, reason: '최신 회차에 나왔다');
      expect(gaps[1], 2, reason: '1회차 이후 두 회차가 지났다');
    });

    test('오래 안 나온 순으로 정렬한다', () {
      final draws = [
        draw(1, [1, 2, 3, 4, 5, 6]),
        draw(2, [7, 8, 9, 10, 11, 12]),
      ];

      final top = droughts(draws, limit: 3);

      expect(top.length, 3);
      expect(top.first.gap, greaterThanOrEqualTo(top.last.gap));
    });

    test('한 번도 안 나온 번호가 가장 오래된 것으로 온다', () {
      // 45개 전체를 다루므로 '한 번도 없음'이 반드시 생긴다.
      // null이나 -1로 새어나가면 화면에서 이상한 값이 보인다.
      final draws = [draw(1, [1, 2, 3, 4, 5, 6])];

      final top = droughts(draws, limit: 1);

      expect(top.single.gap, 1, reason: '보유 회차 수를 넘지 않는다');
      expect([1, 2, 3, 4, 5, 6].contains(top.single.number), isFalse);
    });

    test('limit이 없으면 45개를 모두 준다', () {
      expect(droughts([draw(1, [1, 2, 3, 4, 5, 6])]).length, 45);
    });
  });

  group('자동/수동 비율', () {
    test('건수를 합산한다', () {
      final draws = [
        draw(1, [1, 2, 3, 4, 5, 6], auto: 5, manual: 3, semi: 1),
        draw(2, [1, 2, 3, 4, 5, 6], auto: 2, manual: 1, semi: 0),
      ];

      final m = methodTotals(draws);

      expect(m.auto, 7);
      expect(m.manual, 4);
      expect(m.semi, 1);
      expect(m.total, 12);
    });

    test('값이 없는 옛 회차만 있으면 합이 0이다', () {
      // 261회차 이하는 원본에 자동/수동 구분이 없다.
      // 화면은 이걸 보고 '자료 없음'으로 갈라야 한다 — 0으로 나누면 안 된다
      final m = methodTotals([draw(1, [1, 2, 3, 4, 5, 6])]);

      expect(m.total, 0);
    });
  });
}
