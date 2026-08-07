/// 한 회차에 1등을 낸 판매점.
class WinningStore {
  const WinningStore({
    required this.shopId,
    required this.name,
    required this.address,
    required this.method,
    required this.games,
  });

  final String shopId;
  final String name;
  final String address;

  /// 자동 / 수동 / 반자동.
  final String method;

  /// 이 매장에서 나온 1등 게임 수.
  ///
  /// 한 매장이 같은 회차에 1등을 여러 번 내는 일이 실제로 있다
  /// (1234회차 노다지복권방 2건). 같은 줄이 두 번 보이면 오류처럼 읽히므로
  /// 묶어서 게임 수로 보여준다.
  final int games;

  factory WinningStore.fromJson(Map<String, dynamic> json) => WinningStore(
        shopId: json['shopId'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        method: json['method'] as String? ?? '',
        games: 1,
      );

  WinningStore _plusGame() => WinningStore(
        shopId: shopId,
        name: name,
        address: address,
        method: method,
        games: games + 1,
      );
}

/// 회차별 1등 판매점. 배치의 recent-stores.json과 1:1 대응한다.
class RecentStores {
  const RecentStores(this.byRound);

  /// 회차 → 판매점 목록. 목록이 비어 있으면 그 회차는 1등이 없었다는 뜻이다.
  final Map<int, List<WinningStore>> byRound;

  factory RecentStores.fromJson(Map<String, dynamic> json) => RecentStores({
        for (final e in json.entries)
          int.parse(e.key): _merge([
            for (final s in e.value as List)
              WinningStore.fromJson(s as Map<String, dynamic>)
          ]),
      });

  /// 같은 매장의 여러 건을 한 줄로 묶는다. 원래 순서를 지킨다.
  static List<WinningStore> _merge(List<WinningStore> stores) {
    final byShop = <String, WinningStore>{};
    for (final s in stores) {
      final seen = byShop[s.shopId];
      byShop[s.shopId] = seen == null ? s : seen._plusGame();
    }
    return byShop.values.toList();
  }

  /// 회차 내림차순 — 최신이 앞이다.
  List<int> get rounds => byRound.keys.toList()..sort((a, b) => b.compareTo(a));

  /// 자료가 있는 가장 최근 회차. 하나도 없으면 null.
  int? get latestRound => rounds.isEmpty ? null : rounds.first;
}
