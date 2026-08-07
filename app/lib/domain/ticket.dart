import 'draw.dart';
import 'match_result.dart';
import 'prize.dart';

/// 로또 용지 한 장. 보통 A~E 다섯 게임이 찍혀 있다.
///
/// 저장하는 MyNumbers와 성격이 다르다. 이쪽은 **한 회차짜리 일회성**이라
/// 확인하고 나면 남길 이유가 없다. 매주 5~10장을 사는 사람이 번호를 일일이
/// 넣고 나중에 지우는 부담을 없애기 위한 것이다.
class Ticket {
  Ticket({required List<List<int>> games, this.round})
      : games = List.unmodifiable(
            games.map((g) => List<int>.unmodifiable([...g]..sort())));

  /// 각 게임의 번호 6개. 항상 오름차순.
  final List<List<int>> games;

  /// 용지에 찍힌 회차. 손으로 입력한 경우엔 알 수 없어 null이다.
  final int? round;

  /// A, B, C… 용지에 인쇄된 것과 같은 순서.
  List<String> get labels => [
        for (var i = 0; i < games.length; i++)
          String.fromCharCode('A'.codeUnitAt(0) + i)
      ];

  List<MatchResult> check(Draw draw) =>
      [for (final g in games) MatchResult.of(mine: g, draw: draw)];

  /// 이 장에서 가장 높은 등수. 요약 한 줄로 보여주기 위한 것.
  Rank bestRank(Draw draw) => check(draw)
      .map((r) => r.rank)
      .reduce((a, b) => a.index <= b.index ? a : b);

  int winningCount(Draw draw) =>
      check(draw).where((r) => r.rank != Rank.none).length;

  /// 용지 QR을 해석한다. 로또 QR이 아니면 null.
  ///
  /// 실물에서 확인한 형식 (2026-08-07):
  /// ```
  /// http://qr.dhlottery.co.kr/?v=1234q020709131430q0508...q011617242935187712019714800177
  ///                              ────  ─────────────                    ──────────────────
  ///                              회차   마커+번호12자리 × 게임수              꼬리(일련번호)
  /// ```
  /// 서버에 묻지 않고 이 자리에서 해석한다. 그래서 신호가 없는 곳에서도
  /// 즉시 확인된다 — 공식 QR 확인이 못 하는 지점이다.
  static Ticket? fromQr(String raw) {
    final match = RegExp(r'[?&]v=([0-9a-zA-Z]+)').firstMatch(raw);
    if (match == null) return null;

    final payload = match.group(1)!;
    if (payload.length < 4) return null;

    final round = int.tryParse(payload.substring(0, 4));
    if (round == null) return null;

    // 마커(자동/수동/반자동) + 12자리가 한 게임. 꼬리의 일련번호는 마커가
    // 없으므로 자연히 걸러진다.
    final games = <List<int>>[];
    for (final g in RegExp(r'([a-zA-Z])(\d{12})').allMatches(payload)) {
      final digits = g.group(2)!;
      final numbers = [
        for (var i = 0; i < 12; i += 2) int.parse(digits.substring(i, i + 2))
      ];
      if (!_isValidGame(numbers)) return null;
      games.add(numbers);
    }
    if (games.isEmpty) return null;

    return Ticket(games: games, round: round);
  }

  static bool _isValidGame(List<int> numbers) =>
      numbers.length == 6 &&
      numbers.toSet().length == 6 &&
      numbers.every((n) => n >= 1 && n <= 45);
}
