/// 한 회차의 당첨 정보. 배치가 만든 draws.json 항목과 1:1 대응한다.
class Draw {
  const Draw({
    required this.round,
    required this.date,
    required this.numbers,
    required this.bonus,
    required this.firstWinners,
    required this.firstAmount,
    required this.totalSales,
    required this.winAuto,
    required this.winManual,
    required this.winSemi,
  });

  final int round;
  final DateTime date;

  /// 당첨번호 6개. 항상 오름차순.
  final List<int> numbers;
  final int bonus;

  final int firstWinners;
  final int firstAmount;

  /// 총 판매금액. 배치가 wholEpsdSumNtslAmt를 넣어준다 —
  /// 당첨금 총액(판매액의 50%)과 헷갈리기 쉬운 값이다.
  final int totalSales;

  /// 1등 당첨의 자동/수동/반자동 건수. 262회차 이전은 원본에 값이 없어 0이다.
  final int winAuto;
  final int winManual;
  final int winSemi;

  factory Draw.fromJson(Map<String, dynamic> json) {
    final numbers = List<int>.from(json['numbers'] as List)..sort();
    return Draw(
      round: json['round'] as int,
      date: DateTime.parse(json['date'] as String),
      numbers: numbers,
      bonus: json['bonus'] as int,
      firstWinners: json['firstWinners'] as int,
      firstAmount: json['firstAmount'] as int,
      totalSales: json['totalSales'] as int,
      winAuto: json['winAuto'] as int? ?? 0,
      winManual: json['winManual'] as int? ?? 0,
      winSemi: json['winSemi'] as int? ?? 0,
    );
  }

  /// 내려받은 회차를 기기에 보관할 때 쓴다. 배치가 내보내는 형식과 같다.
  Map<String, dynamic> toJson() => {
        'round': round,
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'numbers': numbers,
        'bonus': bonus,
        'firstWinners': firstWinners,
        'firstAmount': firstAmount,
        'totalSales': totalSales,
        'winAuto': winAuto,
        'winManual': winManual,
        'winSemi': winSemi,
      };

  /// 당첨금·판매금액이 아직 확정되지 않은 상태.
  ///
  /// 추첨 직후에는 당첨번호만 나오고 집계는 나중에 채워진다.
  /// 1등이 실제로 0명인 회차(289·295)도 총 판매금액은 정상값을 가지므로,
  /// 그걸로 '집계 전'과 '당첨자 없음'을 구분한다.
  bool get isSettled => totalSales > 0;
}

/// 번호 볼 색상 구간 (설계 문서 §7 F1).
enum BallGroup { yellow, blue, red, grey, green }

BallGroup ballGroup(int number) {
  if (number <= 10) return BallGroup.yellow;
  if (number <= 20) return BallGroup.blue;
  if (number <= 30) return BallGroup.red;
  if (number <= 40) return BallGroup.grey;
  return BallGroup.green;
}
