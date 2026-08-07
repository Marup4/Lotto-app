import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/draw.dart';

/// GitHub Pages에 올라온 최신 회차를 가져온다.
///
/// 앱은 동행복권을 직접 두드리지 않는다(설계 원칙 1). 배치가 추첨 직후부터
/// 20분 간격으로 갱신해 정적 JSON으로 올려두면, 앱은 그걸 읽기만 한다.
/// 사용자 IP로 크롤링이 나가지 않으므로 차단 위험도 없다.
///
/// **실패는 전부 조용히 삼킨다.** 새 데이터를 못 받아도 번들·캐시 데이터로
/// 아무 일 없이 동작해야 한다 (설계 문서 §5-② graceful degradation).
class DrawSync {
  DrawSync({http.Client? client, this.baseUrl = _defaultBase})
      : _client = client ?? http.Client();

  static const _defaultBase = 'https://marup4.github.io/Lotto-app';
  static const _cacheKey = 'cached_draws';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final String baseUrl;

  /// 서버에 새 회차가 있으면 받아서 보관하고 돌려준다.
  /// 받을 게 없거나 실패하면 null — 호출부는 기존 데이터를 그대로 쓰면 된다.
  Future<List<Draw>?> refresh({required int localLatest}) async {
    try {
      final manifest = await _getJson('manifest.json');
      final latest = (manifest as Map<String, dynamic>)['latestRound'] as int?;
      // manifest만 보고 끝낼 수 있으면 18KB를 받지 않는다.
      if (latest == null || latest <= localLatest) return null;

      final body = await _getJson('draws-latest.json');
      final draws = _parse(body);
      if (draws.isEmpty) return null;

      await _store(draws);
      return draws;
    } catch (_) {
      return null;
    }
  }

  /// 지난번에 받아둔 회차. 없거나 깨졌으면 null.
  Future<List<Draw>?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final draws = _parse(jsonDecode(raw));
      return draws.isEmpty ? null : draws;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _getJson(String file) async {
    final response =
        await _client.get(Uri.parse('$baseUrl/$file')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    // 한글이 없는 파일이지만 서버 헤더에 기대지 않고 UTF-8로 못 박는다.
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  List<Draw> _parse(dynamic body) => (body as List)
      .map((e) => Draw.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => a.round.compareTo(b.round));

  Future<void> _store(List<Draw> draws) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _cacheKey, jsonEncode([for (final d in draws) d.toJson()]));
  }
}
