/// 사용자가 저장한 번호 한 세트 (설계 문서 §6 my_numbers).
class MyNumbers {
  MyNumbers({
    required this.id,
    required List<int> numbers,
    required this.label,
    required this.createdAt,
  }) : numbers = List.unmodifiable([...numbers]..sort());

  final String id;

  /// 항상 오름차순.
  final List<int> numbers;

  /// A~E 같은 짧은 이름. 여러 게임을 한눈에 구분하기 위한 것.
  final String label;

  final DateTime createdAt;

  factory MyNumbers.fromJson(Map<String, dynamic> json) => MyNumbers(
        id: json['id'] as String,
        numbers: List<int>.from(json['numbers'] as List),
        label: json['label'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'numbers': numbers,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 1~45 그리드에서 고르는 중인 상태.
///
/// 키패드 대신 그리드를 쓰는 이유는 오입력을 줄이기 위함이다(설계 문서 §7 F2).
/// 그 취지대로 여섯 개를 넘겨 고를 수 없게 막는다.
class NumberSelection {
  const NumberSelection([this.numbers = const []]);

  /// 오름차순.
  final List<int> numbers;

  static const max = 6;

  bool get isComplete => numbers.length == max;

  bool contains(int n) => numbers.contains(n);

  NumberSelection toggle(int n) {
    if (numbers.contains(n)) {
      return NumberSelection([...numbers]..remove(n));
    }
    if (numbers.length >= max) return this; // 일곱 번째 탭은 무시한다
    return NumberSelection([...numbers, n]..sort());
  }
}
