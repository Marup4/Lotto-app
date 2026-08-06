import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/draw.dart';

/// 번들된 draws.json을 읽어 회차를 공급한다.
///
/// 설계 원칙 3(오프라인 우선): 최초 데이터는 앱에 들어 있으므로
/// 네트워크 없이도 첫 화면이 즉시 뜬다. 신규 회차 증분 동기화는
/// 이후 단계에서 이 위에 얹는다.
class DrawRepository {
  static const _assetPath = 'assets/data/draws.json';

  List<Draw>? _cache;

  /// 회차 오름차순. 앱 수명 동안 한 번만 파싱한다.
  Future<List<Draw>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final text = await rootBundle.loadString(_assetPath);
    final list = (jsonDecode(text) as List)
        .map((e) => Draw.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.round.compareTo(b.round));

    return _cache = list;
  }
}
