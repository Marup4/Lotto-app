import 'package:flutter/material.dart';

import '../data/store_repository.dart';
import '../domain/store_rank.dart';
import '../domain/winning_store.dart';
import 'disclaimer.dart';

/// ⑤ 판매점 탭 (설계 문서 §8, F7).
///
/// 두 화면을 위쪽 전환으로 오간다.
///   - 이번 회차: 최근 회차의 1등 판매점. 매주 바뀌는 유일한 판매점 정보다
///   - 역대 명당: 1등을 많이 낸 매장 TOP 50
///
/// **지역 필터는 두지 않는다.** 상위 50개에는 강원·대전·제주·세종이 한 곳도
/// 못 든다(2026-08-07 실측). 그 지역 사용자에게는 "우리 지역엔 명당이 없다"로
/// 읽히는데, 사실은 목록이 그 지역을 담지 못한 것이다. 지킬 수 없는 약속은
/// 하지 않는다. 대신 전국을 빠짐없이 다루는 '이번 회차'를 기본으로 둔다.
///
/// ⚠️ 어느 매장에서 사든 당첨 확률은 같다. 하단 안내를 고정 노출한다.
class StoresTab extends StatefulWidget {
  const StoresTab({super.key, this.repository});

  final StoreRepository? repository;

  @override
  State<StoresTab> createState() => _StoresTabState();
}

enum _View { recent, allTime }

class _StoresTabState extends State<StoresTab> {
  late final StoreRepository _repo = widget.repository ?? StoreRepository();
  late final Future<(RecentStores, Ranking)> _data = _load();

  _View _view = _View.recent;

  Future<(RecentStores, Ranking)> _load() async =>
      (await _repo.loadRecent(), await _repo.loadRanking());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(RecentStores, Ranking)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // 설계 원칙: 에러 화면으로 사용자를 막지 않는다.
          return const Center(child: Text('판매점 정보를 읽지 못했습니다'));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (recent, ranking) = data;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: SegmentedButton<_View>(
                segments: const [
                  ButtonSegment(value: _View.recent, label: Text('이번 회차')),
                  ButtonSegment(value: _View.allTime, label: Text('역대 명당')),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
                showSelectedIcon: false,
              ),
            ),
            Expanded(
              child: _view == _View.recent
                  ? _RecentView(recent: recent)
                  : _RankingView(ranking: ranking),
            ),
          ],
        );
      },
    );
  }
}

/// 최근 회차의 1등 판매점. 기본은 자료가 있는 가장 최근 회차다.
///
/// 추첨 직후에는 판매점이 확정되지 않아 신규 회차가 아직 없을 수 있다.
/// 그럴 때는 직전 회차를 보여준다 — 빈 화면보다 낫다.
class _RecentView extends StatefulWidget {
  const _RecentView({required this.recent});

  final RecentStores recent;

  @override
  State<_RecentView> createState() => _RecentViewState();
}

class _RecentViewState extends State<_RecentView> {
  late int? _round = widget.recent.latestRound;

  @override
  Widget build(BuildContext context) {
    final round = _round;
    if (round == null) {
      return const Center(child: Text('아직 판매점 자료가 없습니다'));
    }
    final stores = widget.recent.byRound[round] ?? const <WinningStore>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          children: [
            DropdownButton<int>(
              value: round,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              style: Theme.of(context).textTheme.titleLarge,
              items: [
                for (final r in widget.recent.rounds)
                  DropdownMenuItem(
                      value: r,
                      child: Text('$r회',
                          style: Theme.of(context).textTheme.bodyLarge)),
              ],
              onChanged: (r) => setState(() => _round = r),
            ),
            const SizedBox(width: 6),
            Text('1등 판매점',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        if (stores.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('이 회차는 1등 당첨자가 없습니다')),
          )
        else
          for (final s in stores) _WinnerRow(store: s),
        const SizedBox(height: 24),
        const Disclaimer(
          '많이 팔린 매장일수록 1등이 나올 기회도 많습니다. '
          '어느 매장에서 사든 당첨 확률은 같습니다.',
        ),
      ],
    );
  }
}

class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.store});

  final WinningStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined,
              size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(store.address,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 같은 매장에서 1등이 여러 번 나온 회차가 있다 (1234회차 2건).
          Text(store.games > 1 ? '${store.method} ${store.games}게임' : store.method,
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// 역대 1등 배출 매장 TOP 50.
class _RankingView extends StatelessWidget {
  const _RankingView({required this.ranking});

  final Ranking ranking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (ranking.online != null) ...[
          _OnlineCard(ranking.online!),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < ranking.stores.length; i++)
          _StoreRow(store: ranking.stores[i], rank: i + 1),
        const SizedBox(height: 24),
        const Disclaimer(
          '많이 팔린 매장일수록 1등이 나올 기회도 많습니다. '
          '어느 매장에서 사든 당첨 확률은 같습니다.',
        ),
      ],
    );
  }
}

/// 온라인 구매분. 실물 매장이 아니라 랭킹에서 뺐지만, 얼마나 나오는지
/// 궁금해하는 사람이 있어 위에 따로 보여준다 (2026-08-07 결정).
class _OnlineCard extends StatelessWidget {
  const _OnlineCard(this.online);

  final OnlineChannel online;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.language, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('동행복권 인터넷 구매',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('1등 ${online.count}회 · 최근 ${online.latestRound}회차',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  Text('실물 매장이 아니라 아래 순위에서는 제외했습니다.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store, required this.rank});

  final StoreRank store;
  final int rank;

  @override
  Widget build(BuildContext context) {
    // 자동/수동은 '명당'을 보는 재미의 일부다 — 수동이 많은 집은 성격이 다르다.
    final methods = [
      for (final k in const ['자동', '수동', '반자동'])
        if ((store.byMethod[k] ?? 0) > 0) '$k ${store.byMethod[k]}'
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text('$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade500,
                )),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(store.address,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text('$methods · 최근 ${store.latestRound}회차',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${store.count}회',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
