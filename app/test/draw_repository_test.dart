import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotto_app/data/draw_repository.dart';
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

MockClient serverWith(int latest) => MockClient((req) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.Response(jsonEncode({'latestRound': latest}), 200);
      }
      return http.Response(
          jsonEncode(
              [for (var r = latest - 99; r <= latest; r++) drawJson(r)]),
          200);
    });

final deadServer = MockClient((_) async => throw Exception('연결 없음'));

void main() {
  // rootBundle을 쓰려면 바인딩이 있어야 한다.
  // 번들 에셋(최근 100회차)을 테스트에서도 실제로 읽는다.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('번들만 있으면 번들을 쓴다', () async {
    final repo = DrawRepository(sync: DrawSync(client: deadServer));

    final draws = await repo.loadAll();

    expect(draws, isNotEmpty);
    expect(draws.length, 100);
  });

  test('서버에 새 회차가 있으면 그것으로 갱신된다', () async {
    final repo = DrawRepository(sync: DrawSync(client: serverWith(1300)));

    final draws = await repo.loadAll();

    expect(draws.last.round, 1300);
    expect(draws.first.round, 1201, reason: '창이 통째로 밀려야 한다');
  });

  test('네트워크가 죽어도 화면은 뜬다', () async {
    // 설계 문서 §5-②: 신규 데이터가 없어도 에러 화면을 띄우지 않는다
    final repo = DrawRepository(sync: DrawSync(client: deadServer));

    expect(await repo.loadAll(), isNotEmpty);
  });

  test('한 번 갱신하면 다음 실행에서는 캐시가 번들을 이긴다', () async {
    await DrawRepository(sync: DrawSync(client: serverWith(1300))).loadAll();

    // 앱을 다시 켰는데 이번엔 네트워크가 없다
    final draws =
        await DrawRepository(sync: DrawSync(client: deadServer)).loadAll();

    expect(draws.last.round, 1300, reason: '번들(1235)로 되돌아가면 안 된다');
  });

  test('같은 인스턴스는 두 번 파싱하지 않는다', () async {
    final repo = DrawRepository(sync: DrawSync(client: deadServer));

    expect(identical(await repo.loadAll(), await repo.loadAll()), isTrue);
  });


  test('번들이 캐시보다 최신이면 번들을 쓴다', () async {
    // 앱을 업데이트하면 번들에 더 최신 회차가 들어온다. 그런데 기기에는
    // 예전에 받아둔 캐시가 남아 있다. 오프라인 상태로 열면 캐시가
    // 이기면서 방금 설치한 새 데이터가 무시된다.
    //
    // 번들의 최신 회차를 숫자로 박지 않는다 — 배치가 매주 갱신하므로
    // 추첨 때마다 테스트가 깨진다 (실제로 1236회차에서 깨졌다).
    final bundleLatest =
        (await DrawRepository(sync: DrawSync(client: deadServer)).loadAll())
            .last
            .round;
    SharedPreferences.setMockInitialValues({
      'cached_draws': jsonEncode([drawJson(bundleLatest - 200)]),
    });

    final draws = await DrawRepository(sync: DrawSync(client: deadServer))
        .loadAll();

    expect(draws.last.round, bundleLatest, reason: '번들이 낡은 캐시를 이겨야 한다');
  });
}
