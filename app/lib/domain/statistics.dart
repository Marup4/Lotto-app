/// ④ 통계 탭의 계산 (설계 문서 §7 F4).
///
/// ⚠️ 이 수치들은 **재미 요소**다. 지난 결과를 세어 보여줄 뿐,
/// 다음 회차에 무엇이 나올지와는 무관하다. 화면 문구에 "예측",
/// "확률이 높다" 같은 표현을 쓰지 않는다 (§7 F3와 같은 원칙).
///
/// 앱이 가진 회차(최근 100회)만으로 계산한다. 서버의 stats.json을
/// 따로 받지 않는 이유가 둘이다.
///   - 미출현 기간은 100회 창으로도 전 회차 계산과 결과가 같다.
///     실측 최대 미출현이 22회차라 창 밖으로 나가는 번호가 없다
///   - 내려받을 파일이 하나 늘면 오프라인 대비와 버전 어긋남을 또 다뤄야 한다
/// 전체 누적 빈도를 보여주기로 방침이 바뀌면 그때는 stats.json이 필요하다 —
/// 1235회를 누적하면 45개가 전부 평균 근처로 수렴해 화면상 의미가 없어서 뺐다.
library;

import 'draw.dart';

/// 로또는 1~45 중 6개를 뽑는다.
const _maxNumber = 45;

/// 번호별 출현 횟수. 1~45가 모두 들어 있고, 안 나온 번호는 0이다.
///
/// [recent]를 주면 최신 [recent] 회차만 센다. 보유 회차보다 크면 전부 센다.
/// 보너스 번호는 세지 않는다 — 1등 기준 통계이기 때문이다.
Map<int, int> frequency(List<Draw> draws, {int? recent}) {
  final counts = {for (var n = 1; n <= _maxNumber; n++) n: 0};
  for (final d in _window(draws, recent)) {
    for (final n in d.numbers) {
      counts[n] = counts[n]! + 1;
    }
  }
  return counts;
}

/// 번호 하나의 미출현 기간.
typedef Drought = ({int number, int gap});

/// 마지막으로 나온 뒤 지난 회차 수. 오래된 순으로 정렬해 돌려준다.
///
/// 최신 회차에 나온 번호는 0이다. 보유 구간에서 한 번도 안 나온 번호는
/// 보유 회차 수가 되어 자연히 맨 앞에 온다 — '알 수 없음'을 따로 두면
/// 화면에서 또 갈라 처리해야 하고, 사용자에게는 어차피 '가장 오래됨'이다.
///
/// [limit]을 주면 그만큼만 돌려준다.
List<Drought> droughts(List<Draw> draws, {int? limit}) {
  // 오름차순 목록의 뒤에서부터 세면 최신이 0이 된다.
  final gaps = <Drought>[];
  for (var n = 1; n <= _maxNumber; n++) {
    var gap = draws.length;
    for (var i = draws.length - 1; i >= 0; i--) {
      if (draws[i].numbers.contains(n)) {
        gap = draws.length - 1 - i;
        break;
      }
    }
    gaps.add((number: n, gap: gap));
  }

  gaps.sort((a, b) => b.gap.compareTo(a.gap));
  return limit == null ? gaps : gaps.take(limit).toList();
}

/// 1등 당첨의 구매 방식별 건수.
typedef MethodTotals = ({int auto, int manual, int semi, int total});

/// 자동/수동/반자동 건수를 합산한다.
///
/// 261회차 이하는 원본에 구분이 없어 전부 0이다. 그런 회차만 모이면
/// [total]이 0이 되므로, 화면은 비율을 계산하기 전에 이 값을 봐야 한다.
MethodTotals methodTotals(List<Draw> draws) {
  var auto = 0, manual = 0, semi = 0;
  for (final d in draws) {
    auto += d.winAuto;
    manual += d.winManual;
    semi += d.winSemi;
  }
  return (auto: auto, manual: manual, semi: semi, total: auto + manual + semi);
}

/// 최신 [recent] 회차. draws는 회차 오름차순이므로 뒤쪽이 최신이다.
Iterable<Draw> _window(List<Draw> draws, int? recent) =>
    recent == null || recent >= draws.length
        ? draws
        : draws.skip(draws.length - recent);
