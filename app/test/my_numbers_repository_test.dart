import 'package:flutter_test/flutter_test.dart';
import 'package:lotto_app/data/my_numbers_repository.dart';
import 'package:lotto_app/domain/my_numbers.dart';
import 'package:shared_preferences/shared_preferences.dart';

MyNumbers entry(String label, List<int> numbers) => MyNumbers(
      id: label,
      numbers: numbers,
      label: label,
      createdAt: DateTime.utc(2026, 8, 1),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장한 번호를 다시 읽어올 수 있다', () async {
    final repo = MyNumbersRepository();
    await repo.add(entry('A', [1, 2, 3, 4, 5, 6]));

    final loaded = await MyNumbersRepository().loadAll();

    expect(loaded.map((e) => e.label), ['A']);
    expect(loaded.single.numbers, [1, 2, 3, 4, 5, 6]);
  });

  test('저장된 것이 없으면 빈 목록이다', () async {
    expect(await MyNumbersRepository().loadAll(), isEmpty);
  });

  test('최근에 추가한 것이 위로 온다', () async {
    final repo = MyNumbersRepository();
    await repo.add(entry('A', [1, 2, 3, 4, 5, 6]));
    await repo.add(entry('B', [7, 8, 9, 10, 11, 12]));

    expect((await repo.loadAll()).map((e) => e.label), ['B', 'A']);
  });

  test('지운 번호는 사라진다', () async {
    final repo = MyNumbersRepository();
    await repo.add(entry('A', [1, 2, 3, 4, 5, 6]));
    await repo.add(entry('B', [7, 8, 9, 10, 11, 12]));

    await repo.remove('A');

    expect((await repo.loadAll()).map((e) => e.label), ['B']);
  });

  test('저장 내용이 깨져 있어도 앱이 죽지 않는다', () async {
    // 사용자를 에러 화면으로 막지 않는다는 원칙(설계 문서 §5-②)을 저장소에도 적용
    SharedPreferences.setMockInitialValues({'my_numbers': '{{{망가진 JSON'});

    expect(await MyNumbersRepository().loadAll(), isEmpty);
  });
}
