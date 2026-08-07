import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotto_app/data/store_repository.dart';
import 'package:lotto_app/domain/winning_store.dart';
import 'package:lotto_app/ui/stores_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> shop(String id, String name, int count,
        {String sido = '서울'}) =>
    {
      'shopId': id,
      'name': name,
      'address': '$sido 어딘가 1',
      'sido': sido,
      'sigungu': '어딘가구',
      'count': count,
      'latestRound': 1200,
      'byMethod': {'자동': count},
      'lat': 37.5,
      'lon': 127.0,
    };

Map<String, dynamic> winner(String id, String name, {String method = '자동'}) =>
    {'shopId': id, 'name': name, 'address': '서울 어딘가 1', 'method': method};

final ranking = {
  'online': {
    'count': 118,
    'latestRound': 1225,
    'byMethod': {'자동': 57, '수동': 58, '반자동': 3}
  },
  'stores': [
    shop('A', '스파', 51),
    shop('B', '부일카서비스', 50, sido: '부산'),
  ],
};

final recent = {
  '1234': [
    winner('N', '노다지복권방', method: '수동'),
    winner('N', '노다지복권방', method: '수동'),
    winner('S', '종합가판점'),
  ],
  '1235': [winner('T', '또복이 복권방')],
};

/// ⚠️ `http.Response(문자열, 200)`은 기본 인코딩이 **latin1**이라 한글에서
/// 죽는다. 실제 서버는 바이트를 주므로 테스트도 바이트로 준다 —
/// 이래야 저장소의 utf8.decode 경로까지 실제로 지나간다.
http.Response jsonResponse(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// 서버는 죽어 있다고 본다 — 번들/캐시 경로를 테스트하기 위함이다.
final deadServer = MockClient((_) async => throw Exception('연결 없음'));

MockClient server({Map<String, dynamic>? recentBody}) => MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('manifest.json')) {
        return jsonResponse({
          'files': {
            'store-ranking.json': 'r1',
            'recent-stores.json': 'w1',
          }
        });
      }
      if (path.endsWith('recent-stores.json')) {
        return jsonResponse(recentBody ?? recent);
      }
      return jsonResponse(ranking);
    });

/// 저장소를 미리 한 번 돌려 캐시를 채운 뒤 화면을 띄운다.
///
/// 함정이 둘 있다.
///   - `pumpAndSettle`을 쓰면 안 된다. 로딩 스피너가 무한 애니메이션이라
///     화면이 영영 '정지'하지 않아 타임아웃으로 죽는다.
///   - 저장소를 그냥 await 하면 교착된다. SharedPreferences와 rootBundle은
///     플랫폼 채널을 쓰는데 그 응답은 테스트 프레임이 돌아야 처리되고,
///     우리는 프레임을 돌리기 전에 기다리는 셈이 된다.
///     `runAsync`로 진짜 비동기 구간에서 처리해야 한다.
Future<void> pump(WidgetTester tester, StoreRepository repo) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await repo.loadRecent();
    await repo.loadRanking();
  });
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StoresTab(repository: repo))));
  await tester.pump();
}

Future<void> settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('회차별 판매점', () {
    test('같은 매장의 여러 건을 한 줄로 묶는다', () {
      // 1234회차 노다지복권방이 실제로 2건이다. 두 줄로 보이면 오류로 읽힌다
      final r = RecentStores.fromJson(recent);

      final stores = r.byRound[1234]!;
      expect(stores.length, 2);
      expect(stores.firstWhere((s) => s.shopId == 'N').games, 2);
      expect(stores.firstWhere((s) => s.shopId == 'S').games, 1);
    });

    test('최신 회차가 앞에 온다', () {
      final r = RecentStores.fromJson(recent);

      expect(r.rounds, [1235, 1234]);
      expect(r.latestRound, 1235);
    });

    test('자료가 하나도 없으면 latestRound가 null이다', () {
      expect(RecentStores.fromJson({}).latestRound, isNull);
    });

    test('1등이 없는 회차는 빈 목록으로 남는다', () {
      // 289·295회처럼 진짜 0명인 회차. '자료 없음'과 구별해야 한다
      final r = RecentStores.fromJson({'1235': []});

      expect(r.byRound[1235], isEmpty);
      expect(r.latestRound, 1235);
    });
  });

  group('저장소', () {
    test('네트워크가 죽어도 번들로 뜬다', () async {
      final repo = StoreRepository(client: deadServer);

      expect((await repo.loadRanking()).stores, isNotEmpty);
      expect((await repo.loadRecent()).rounds.length, 10,
          reason: '번들에는 최근 10회차가 들어 있다');
    });

    test('서버 파일이 다르면 그걸 쓴다', () async {
      final r = await StoreRepository(client: server()).loadRanking();

      expect(r.stores.first.name, '스파');
    });

    test('두 파일의 해시를 따로 본다', () async {
      // 한 키를 공유하면 랭킹만 바뀌었을 때 최근 회차를 헛되이 다시 받는다
      SharedPreferences.setMockInitialValues(
          {'cached_hash_store-ranking.json': 'r1'});
      final asked = <String>[];
      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('manifest.json')) {
          return jsonResponse({
            'files': {
              'store-ranking.json': 'r1',
              'recent-stores.json': 'w1',
            }
          });
        }
        asked.add(path.split('/').last);
        return jsonResponse(path.endsWith('recent-stores.json') ? recent : ranking);
      });

      final repo = StoreRepository(client: client);
      await repo.loadRanking();
      await repo.loadRecent();

      expect(asked, ['recent-stores.json'], reason: '랭킹은 해시가 같아 건너뛴다');
    });

    test('같은 인스턴스는 두 번 파싱하지 않는다', () async {
      final repo = StoreRepository(client: deadServer);

      expect(identical(await repo.loadRanking(), await repo.loadRanking()), isTrue);
    });
  });

  group('화면', () {
    testWidgets('기본은 이번 회차 판매점이다', (tester) async {
      await pump(tester, StoreRepository(client: server()));

      expect(find.text('1등 판매점'), findsOneWidget);
      expect(find.text('또복이 복권방'), findsOneWidget);
      expect(find.text('스파'), findsNothing, reason: '역대 명당은 아직 안 보인다');
    });

    testWidgets('역대 명당으로 전환하면 랭킹이 나온다', (tester) async {
      await pump(tester, StoreRepository(client: server()));

      await tester.tap(find.text('역대 명당'));
      await settle(tester);

      expect(find.text('스파'), findsOneWidget);
      expect(find.text('동행복권 인터넷 구매'), findsOneWidget);
      expect(find.text('1등 118회 · 최근 1225회차'), findsOneWidget);
    });

    testWidgets('지역 필터는 두지 않는다', (tester) async {
      // 상위 50개에 강원·대전·제주·세종이 한 곳도 못 든다.
      // 지킬 수 없는 약속이라 뺐다 — 되살아나면 이 테스트가 잡는다.
      await pump(tester, StoreRepository(client: server()));
      await tester.tap(find.text('역대 명당'));
      await settle(tester);

      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('전체'), findsNothing);
    });

    testWidgets('회차를 바꾸면 그 회차 판매점이 나온다', (tester) async {
      await pump(tester, StoreRepository(client: server()));

      await tester.tap(find.text('1235회'));
      await settle(tester);
      await tester.tap(find.text('1234회').last);
      await settle(tester);

      expect(find.text('종합가판점'), findsOneWidget);
      // 같은 매장 2건은 한 줄로 묶어 게임 수를 보여준다
      expect(find.text('수동 2게임'), findsOneWidget);
    });

    testWidgets('1등이 없는 회차는 그렇게 말한다', (tester) async {
      await pump(tester,
          StoreRepository(client: server(recentBody: {'1235': []})));

      expect(find.text('이 회차는 1등 당첨자가 없습니다'), findsOneWidget);
    });

    testWidgets('당첨 확률이 같다는 안내가 항상 있다', (tester) async {
      // 설계 문서 §12. '명당'을 보여주는 화면이라 더 중요하다
      await pump(tester, StoreRepository(client: server()));

      expect(find.textContaining('당첨 확률은 같습니다'), findsOneWidget);
    });
  });
}
