import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/store_rank.dart';
import '../domain/winning_store.dart';

/// ⑤ 판매점 탭이 쓰는 두 파일을 공급한다 — 역대 랭킹과 최근 회차 판매점.
///
/// [DrawRepository]와 같은 3단 구조다: 서버 → 기기 보관본 → 앱 번들.
/// 어느 단계가 실패해도 화면은 뜬다 (설계 문서 §5-②).
///
/// 회차 번호가 아니라 **manifest의 파일 해시**로 갱신을 판단한다.
/// 판매점은 추첨 직후에 확정되지 않고 나중에 채워지므로, 회차가 그대로여도
/// 내용만 바뀌는 구간이 실제로 있다. 회차로 판단하면 그걸 놓친다.
class StoreRepository {
  StoreRepository({http.Client? client, this.baseUrl = _defaultBase})
      : _client = client ?? http.Client();

  static const _defaultBase = 'https://marup4.github.io/Lotto-app';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final String baseUrl;

  Ranking? _ranking;
  RecentStores? _recent;

  /// 역대 1등 배출 매장 랭킹. 앱 수명 동안 한 번만 만든다.
  Future<Ranking> loadRanking() async => _ranking ??= Ranking.fromJson(
        await _load('store-ranking.json', _rankingRecency),
      );

  /// 최근 회차의 1등 판매점.
  Future<RecentStores> loadRecent() async => _recent ??= RecentStores.fromJson(
        await _load('recent-stores.json', _recentRecency),
      );

  /// 서버 → (보관본 · 번들 중 최신) 순으로 시도해 가장 새 것을 돌려준다.
  ///
  /// 보관본을 무조건 앞세우면, 앱을 업데이트해 번들에 새 자료가 들어와도
  /// 오프라인에서는 예전 캐시가 이겨 방금 설치한 데이터가 무시된다.
  /// 이 파일들에는 회차 번호가 없으므로 [recency]로 새것을 가린다.
  Future<Map<String, dynamic>> _load(
    String file,
    int Function(Map<String, dynamic>) recency,
  ) async {
    final bundle = await _fromBundle(file);
    final cached = await _fromPrefs(file);
    final local = cached != null && recency(cached) >= recency(bundle)
        ? cached
        : bundle;
    return await _refresh(file) ?? local;
  }

  /// 랭킹의 새것 정도 — 가장 최근 배출 회차. 자료가 늘수록 커진다.
  static int _rankingRecency(Map<String, dynamic> json) {
    var latest = 0;
    for (final s in json['stores'] as List? ?? const []) {
      final r = (s as Map<String, dynamic>)['latestRound'] as int? ?? 0;
      if (r > latest) latest = r;
    }
    return latest;
  }

  /// 최근 회차 판매점의 새것 정도 — 담긴 회차 중 가장 큰 것.
  static int _recentRecency(Map<String, dynamic> json) {
    var latest = 0;
    for (final key in json.keys) {
      final r = int.tryParse(key) ?? 0;
      if (r > latest) latest = r;
    }
    return latest;
  }

  /// 서버 파일이 보관본과 다르면 받아서 보관한다.
  /// 받을 게 없거나 실패하면 null — 호출부는 기존 것을 그대로 쓴다.
  Future<Map<String, dynamic>?> _refresh(String file) async {
    try {
      final manifest = await _getJson('manifest.json') as Map<String, dynamic>;
      final hash = (manifest['files'] as Map<String, dynamic>?)?[file];
      // 판매점이 전량 모이기 전에는 이 파일들이 만들어지지 않는다.
      if (hash is! String) return null;

      final prefs = await SharedPreferences.getInstance();
      // manifest만 보고 끝낼 수 있으면 본문을 받지 않는다.
      if (prefs.getString(_hashKey(file)) == hash) return null;

      final body = await _getJson(file) as Map<String, dynamic>;
      if (body.isEmpty) return null;

      await prefs.setString(_cacheKey(file), jsonEncode(body));
      await prefs.setString(_hashKey(file), hash);
      return body;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fromPrefs(String file) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(file));
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _fromBundle(String file) async {
    final text = await rootBundle.loadString('assets/data/$file');
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<dynamic> _getJson(String file) async {
    final response =
        await _client.get(Uri.parse('$baseUrl/$file')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    // 매장명·주소가 한글이다. 서버 헤더에 기대지 않고 UTF-8로 못 박는다.
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  String _cacheKey(String file) => 'cached_$file';
  String _hashKey(String file) => 'cached_hash_$file';
}
