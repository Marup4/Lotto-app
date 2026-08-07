import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/domain/my_numbers.dart';

void main() {
  group('저장/복원', () {
    test('JSON으로 왕복해도 값이 유지된다', () {
      final entry = MyNumbers(
        id: 'abc',
        numbers: const [3, 8, 15, 22, 31, 44],
        label: 'A',
        createdAt: DateTime.utc(2026, 8, 1, 12, 30),
      );

      final restored = MyNumbers.fromJson(entry.toJson());

      expect(restored.id, entry.id);
      expect(restored.numbers, entry.numbers);
      expect(restored.label, entry.label);
      expect(restored.createdAt, entry.createdAt);
    });

    test('번호는 항상 오름차순으로 보관한다', () {
      final entry = MyNumbers(
        id: 'x',
        numbers: const [44, 3, 22, 8, 31, 15],
        label: 'A',
        createdAt: DateTime.utc(2026, 8, 1),
      );

      expect(entry.numbers, [3, 8, 15, 22, 31, 44]);
    });
  });

  group('번호 고르기', () {
    test('처음에는 아무것도 안 골라져 있다', () {
      expect(const NumberSelection().numbers, isEmpty);
      expect(const NumberSelection().isComplete, isFalse);
    });

    test('고른 번호는 오름차순으로 쌓인다', () {
      final s = const NumberSelection().toggle(22).toggle(3).toggle(15);

      expect(s.numbers, [3, 15, 22]);
    });

    test('이미 고른 번호를 다시 누르면 빠진다', () {
      final s = const NumberSelection().toggle(7).toggle(9).toggle(7);

      expect(s.numbers, [9]);
    });

    test('여섯 개를 채우면 완성이다', () {
      final s = const NumberSelection()
          .toggle(1).toggle(2).toggle(3).toggle(4).toggle(5).toggle(6);

      expect(s.isComplete, isTrue);
    });

    test('여섯 개를 넘겨 고를 수 없다', () {
      // 일곱 번째 탭은 무시된다. 오입력을 막는 것이 그리드 입력의 목적이다.
      final s = const NumberSelection()
          .toggle(1).toggle(2).toggle(3).toggle(4).toggle(5).toggle(6)
          .toggle(7);

      expect(s.numbers, [1, 2, 3, 4, 5, 6]);
    });

    test('가득 찬 뒤에도 이미 고른 번호는 뺄 수 있다', () {
      final s = const NumberSelection()
          .toggle(1).toggle(2).toggle(3).toggle(4).toggle(5).toggle(6)
          .toggle(3);

      expect(s.numbers, [1, 2, 4, 5, 6]);
      expect(s.isComplete, isFalse);
    });
  });
}
