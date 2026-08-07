import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotto_app/data/draw_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> drawJson(int round) => {
      'round': round,
      'date': '2026-08-01',
      'numbers': [1, 2, 3, 4, 5, 6],
      'bonus': 7,
      'firstWinners': 1,
      'firstAmount': 1,
      'totalSales': 1,
      'winAuto': 1,
      'winManual': 0,
      'winSemi': 0,
    };

/// 서버가 latest 회차까지 최근 100회를 들고 있는 상황을 흉내낸다.
MockClient serverWith(int latest, {List<String>? log}) => MockClient((req) async {
      log?.add(req.url.path);
      if (req.url.path.endsWith('manifest.json')) {
        return http.Response(
            jsonEncode({'latestRound': latest, 'complete': true}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (req.url.path.endsWith('draws-latest.json')) {
        return http.Response(
            jsonEncode([
              for (var r = latest - 99; r <= latest; r++) drawJson(r)
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('not found', 404);
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('서버가 더 최신이면 내려받아 보관한다', () async {
    final sync = DrawSync(client: serverWith(1236));

    final draws = await sync.refresh(localLatest: 1235);

    expect(draws, isNotNull);
    expect(draws!.last.round, 1236);
    expect(await sync.cached(), isNotNull);
  });

  test('창이 통째로 밀린다', () async {
    // 1136~1235 를 갖고 있었다면 1137~1236 이 되어야 한다
    final draws = await DrawSync(client: serverWith(1236)).refresh(
      localLatest: 1235,
    );

    expect(draws!.first.round, 1137);
    expect(draws.last.round, 1236);
    expect(draws.length, 100);
  });

  test('서버가 최신이 아니면 내려받지 않는다', () async {
    final log = <String>[];
    final sync = DrawSync(client: serverWith(1235, log: log));

    final draws = await sync.refresh(localLatest: 1235);

    expect(draws, isNull, reason: '받을 게 없으면 null');
    expect(log.where((p) => p.endsWith('draws-latest.json')), isEmpty,
        reason: 'manifest만 보고 끝내야 한다');
  });

  test('보관해둔 것을 다음 실행에서 읽는다', () async {
    await DrawSync(client: serverWith(1236)).refresh(localLatest: 1235);

    // 새 인스턴스 = 앱을 다시 켠 상황
    final cached = await DrawSync(client: serverWith(1236)).cached();

    expect(cached!.last.round, 1236);
  });

  group('실패해도 사용자를 막지 않는다 (설계 문서 §5-②)', () {
    test('네트워크가 죽어 있으면 조용히 포기한다', () async {
      final sync = DrawSync(
          client: MockClient((_) async => throw Exception('연결 실패')));

      expect(await sync.refresh(localLatest: 1235), isNull);
    });

    test('서버가 5xx를 주면 조용히 포기한다', () async {
      final sync =
          DrawSync(client: MockClient((_) async => http.Response('', 503)));

      expect(await sync.refresh(localLatest: 1235), isNull);
    });

    test('응답이 깨져 있으면 조용히 포기한다', () async {
      final sync = DrawSync(
          client: MockClient((_) async => http.Response('{{{망가짐', 200)));

      expect(await sync.refresh(localLatest: 1235), isNull);
    });

    test('보관된 내용이 깨져 있으면 없는 것으로 친다', () async {
      SharedPreferences.setMockInitialValues({'cached_draws': '{{{망가짐'});

      expect(await DrawSync(client: serverWith(1236)).cached(), isNull);
    });
  });
}
