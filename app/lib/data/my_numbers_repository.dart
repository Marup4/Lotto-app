import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/my_numbers.dart';

/// 저장한 번호의 영속화.
///
/// 담는 것은 번호 몇 세트뿐이라 SQLite를 끌어올 이유가 없다.
/// 판매점·통계는 배치가 미리 계산해 주므로 앱에서 쿼리할 일이 없다.
class MyNumbersRepository {
  static const _key = 'my_numbers';

  Future<List<MyNumbers>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => MyNumbers.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 저장 내용이 깨졌다고 에러 화면으로 사용자를 막지 않는다 (설계 문서 §5-②).
      return [];
    }
  }

  Future<void> _save(List<MyNumbers> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// 최근에 넣은 것이 위로 오도록 앞에 붙인다.
  Future<void> add(MyNumbers entry) async {
    await _save([entry, ...await loadAll()]);
  }

  Future<void> remove(String id) async {
    final left = (await loadAll()).where((e) => e.id != id).toList();
    await _save(left);
  }
}
