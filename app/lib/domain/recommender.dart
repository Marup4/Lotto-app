import 'dart:math';

/// 번호를 고르는 방식 (설계 문서 §7 F3).
///
/// ⚠️ 이 기능은 **재미 요소**다. 어떤 방식도 당첨 확률을 바꾸지 않는다.
/// 화면 문구에 "예측", "확률이 높다" 같은 표현을 쓰지 않는다.
/// 사실 서술("최근 자주 나온 번호로 뽑기")만 쓰고, 통계와 당첨 확률이
/// 무관하다는 안내를 고정 노출한다.
enum PickMode {
  /// 45개에서 균등하게.
  random,

  /// 많이 나온 번호에 가중.
  hot,

  /// 적게 나온 번호에 가중.
  cold,
}

const _all = 45;
const _pickCount = 6;

/// 번호 여섯 개를 고른다. 항상 오름차순이고 중복이 없다.
///
/// [fixed]는 반드시 포함하고 [excluded]는 절대 넣지 않는다.
/// 둘이 겹치면 고정이 이긴다 — 사용자가 더 최근에 한 의사표시다.
List<int> recommend({
  PickMode mode = PickMode.random,
  Set<int> excluded = const {},
  Set<int> fixed = const {},
  Map<int, int> frequency = const {},
  Random? random,
}) {
  if (fixed.length > _pickCount) {
    throw ArgumentError('고정 번호는 $_pickCount개를 넘을 수 없다: $fixed');
  }

  final rng = random ?? Random();
  final chosen = {...fixed};
  final pool = [
    for (var n = 1; n <= _all; n++)
      if (!chosen.contains(n) && !excluded.contains(n)) n
  ];

  final need = _pickCount - chosen.length;
  if (pool.length < need) {
    throw ArgumentError('고를 수 있는 번호가 모자란다: ${pool.length}개 남음, $need개 필요');
  }

  final weights = _weights(pool, mode, frequency);
  for (var i = 0; i < need; i++) {
    final index = _pickIndex(weights, rng);
    chosen.add(pool.removeAt(index));
    weights.removeAt(index);
  }

  return chosen.toList()..sort();
}

/// 가중치는 항상 1 이상이라, 한 번도 안 나온 번호도 뽑힐 수 있다.
List<int> _weights(List<int> pool, PickMode mode, Map<int, int> frequency) {
  if (mode == PickMode.random || frequency.isEmpty) {
    // growable: 뽑을 때마다 같은 위치를 removeAt 하므로 고정 길이면 안 된다
    return List.filled(pool.length, 1, growable: true);
  }
  final maxCount =
      frequency.values.fold<int>(0, (a, b) => a > b ? a : b);
  return [
    for (final n in pool)
      switch (mode) {
        PickMode.hot => (frequency[n] ?? 0) + 1,
        PickMode.cold => maxCount - (frequency[n] ?? 0) + 1,
        PickMode.random => 1,
      }
  ];
}

int _pickIndex(List<int> weights, Random rng) {
  final total = weights.fold<int>(0, (a, b) => a + b);
  var roll = rng.nextInt(total);
  for (var i = 0; i < weights.length; i++) {
    roll -= weights[i];
    if (roll < 0) return i;
  }
  return weights.length - 1; // 부동소수 없는 정수 연산이라 도달하지 않는다
}
