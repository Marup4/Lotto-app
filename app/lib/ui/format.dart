/// 금액을 한눈에 읽히게 줄여 쓴다.
///
/// 1,854,965,425 → "18억 5,496만원".
/// 원 단위를 다 보여주면 자릿수를 세게 되고, 그건 "빠른 확인"이라는
/// 이 앱의 목적과 어긋난다.
String formatWon(int won) {
  const eokUnit = 100000000;
  const manUnit = 10000;

  if (won >= eokUnit) {
    final eok = won ~/ eokUnit;
    final man = (won % eokUnit) ~/ manUnit;
    return man > 0 ? '${_comma(eok)}억 ${_comma(man)}만원' : '${_comma(eok)}억원';
  }
  if (won >= manUnit) return '${_comma(won ~/ manUnit)}만원';
  return '${_comma(won)}원';
}

String _comma(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
