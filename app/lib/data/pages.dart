import 'dart:convert';

import 'package:http/http.dart' as http;

/// GitHub Pages에 올라간 정적 JSON을 읽는 통로.
///
/// 앱이 서버와 이야기하는 유일한 창구다. 동행복권을 직접 두드리지 않고
/// (설계 원칙 1), 배치가 미리 만들어 올린 파일만 가져온다.
///
/// **주소를 여기 한 곳에만 둔다.** 호스팅을 옮길 일이 생기면 이 상수 하나만
/// 고치면 된다 — 전에 두 곳에 흩어져 있어 한쪽만 바꾸면 절반이 옛 주소로
/// 남는 상태였다.
class Pages {
  Pages({http.Client? client, this.baseUrl = defaultBase})
      : _client = client ?? http.Client();

  static const defaultBase = 'https://marup4.github.io/Lotto-app';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final String baseUrl;

  /// 파일 하나를 받아 파싱한다. 실패하면 던진다 — 삼키는 것은 호출부의 몫이다.
  Future<dynamic> getJson(String file) async {
    final response =
        await _client.get(Uri.parse('$baseUrl/$file')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    // 매장명·주소가 한글이다. 서버 헤더에 기대지 않고 UTF-8로 못 박는다.
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
