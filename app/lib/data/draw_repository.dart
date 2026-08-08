import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/draw.dart';
import 'draw_sync.dart';

/// 화면에 보여줄 회차를 공급한다.
///
/// 세 곳에서 온다. 뒤로 갈수록 오래된 것이고, 앞이 실패하면 다음으로 넘어간다.
///   1. 서버(GitHub Pages) — 새 회차가 있으면 받아서 보관
///   2. 기기에 보관된 것 — 지난번에 받아둔 회차
///   3. 앱에 번들된 것 — 설치 시점의 회차. 네트워크가 없어도 첫 화면이 뜬다
///
/// 어느 단계가 실패해도 화면은 뜬다 (설계 문서 §5-②).
class DrawRepository {
  DrawRepository({DrawSync? sync}) : _sync = sync ?? DrawSync();

  static const _assetPath = 'assets/data/draws.json';

  final DrawSync _sync;
  List<Draw>? _cache;

  /// 회차 오름차순. 앱 수명 동안 한 번만 만든다.
  Future<List<Draw>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    // 둘 중 최신인 쪽이 기준이 된다. 보관본을 무조건 앞세우면, 앱을
    // 업데이트해 번들에 새 회차가 들어와도 오프라인에서는 예전 캐시가
    // 이겨 방금 설치한 데이터가 무시된다.
    final local = _newer(await _sync.cached(), await _fromBundle());
    final fresh = await _sync.refresh(localLatest: local.last.round);

    return _cache = fresh ?? local;
  }

  /// 회차가 더 큰 쪽. 둘 다 회차 오름차순이다.
  List<Draw> _newer(List<Draw>? cached, List<Draw> bundle) =>
      cached != null && cached.last.round >= bundle.last.round
          ? cached
          : bundle;

  Future<List<Draw>> _fromBundle() async {
    final text = await rootBundle.loadString(_assetPath);
    return (jsonDecode(text) as List)
        .map((e) => Draw.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.round.compareTo(b.round));
  }
}
