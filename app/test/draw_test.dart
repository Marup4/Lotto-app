import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/draw.dart';

// 배치가 만든 draws.json 한 항목의 실제 형태
const raw = {
  'round': 1235,
  'date': '2026-08-01',
  'numbers': [6, 7, 11, 15, 39, 43],
  'bonus': 20,
  'firstWinners': 9,
  'firstAmount': 3090961625,
  'totalSales': 115445069000,
  'winAuto': 7,
  'winManual': 2,
  'winSemi': 0,
};

void main() {
  test('배치 JSON을 그대로 읽는다', () {
    final d = Draw.fromJson(raw);

    expect(d.round, 1235);
    expect(d.date, DateTime(2026, 8, 1));
    expect(d.numbers, [6, 7, 11, 15, 39, 43]);
    expect(d.bonus, 20);
    expect(d.firstWinners, 9);
    expect(d.firstAmount, 3090961625);
    expect(d.totalSales, 115445069000);
  });

  test('JSON으로 왕복해도 값이 유지된다', () {
    // 내려받은 회차를 기기에 보관했다가 다시 읽는 경로에서 쓴다
    final restored = Draw.fromJson(Draw.fromJson(raw).toJson());

    expect(restored.round, 1235);
    expect(restored.date, DateTime(2026, 8, 1));
    expect(restored.numbers, [6, 7, 11, 15, 39, 43]);
    expect(restored.bonus, 20);
    expect(restored.totalSales, 115445069000);
    expect(restored.winAuto, 7);
  });

  test('번호는 오름차순으로 정렬해 내놓는다', () {
    final d = Draw.fromJson({...raw, 'numbers': [43, 6, 39, 7, 15, 11]});

    expect(d.numbers, [6, 7, 11, 15, 39, 43]);
  });

  group('번호 볼 색상 (설계 문서 §7 F1)', () {
    test('구간마다 다른 색을 쓴다', () {
      expect(ballGroup(1), BallGroup.yellow);
      expect(ballGroup(10), BallGroup.yellow);
      expect(ballGroup(11), BallGroup.blue);
      expect(ballGroup(20), BallGroup.blue);
      expect(ballGroup(21), BallGroup.red);
      expect(ballGroup(30), BallGroup.red);
      expect(ballGroup(31), BallGroup.grey);
      expect(ballGroup(40), BallGroup.grey);
      expect(ballGroup(41), BallGroup.green);
      expect(ballGroup(45), BallGroup.green);
    });
  });
}
