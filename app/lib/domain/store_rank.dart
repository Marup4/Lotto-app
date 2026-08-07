/// 역대 1등을 많이 낸 매장 하나. 배치의 store-ranking.json 항목과 1:1 대응한다.
class StoreRank {
  const StoreRank({
    required this.shopId,
    required this.name,
    required this.address,
    required this.sido,
    required this.sigungu,
    required this.count,
    required this.latestRound,
    required this.byMethod,
    required this.lat,
    required this.lon,
  });

  final String shopId;
  final String name;
  final String address;

  /// 시도/시군구. 원본이 비어 있으면 빈 문자열이다.
  /// 지금 화면에는 주소를 통째로 쓰지만, 지도를 붙일 때 쓸 수 있다.
  final String sido;
  final String sigungu;

  /// 1등 배출 횟수.
  final int count;

  /// 가장 최근에 1등을 낸 회차. 상호·주소도 이 시점 표기를 따른다.
  final int latestRound;

  /// 구매 방식별 건수 (자동/수동/반자동).
  final Map<String, int> byMethod;

  /// 아직 화면에 쓰지 않는다. 지도를 붙일 때를 위해 배치가 담아준다.
  final double lat;
  final double lon;

  factory StoreRank.fromJson(Map<String, dynamic> json) => StoreRank(
        shopId: json['shopId'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        sido: json['sido'] as String? ?? '',
        sigungu: json['sigungu'] as String? ?? '',
        count: json['count'] as int,
        latestRound: json['latestRound'] as int,
        byMethod: Map<String, int>.from(json['byMethod'] as Map),
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lon: (json['lon'] as num?)?.toDouble() ?? 0,
      );
}

/// 동행복권 인터넷 구매분.
///
/// 실물 매장이 아니라서 랭킹에서는 빼지만, 온라인으로 얼마나 나오는지
/// 궁금해하는 사람이 있어 목록 위에 따로 보여준다 (2026-08-07 결정).
class OnlineChannel {
  const OnlineChannel({
    required this.count,
    required this.latestRound,
    required this.byMethod,
  });

  final int count;
  final int latestRound;
  final Map<String, int> byMethod;

  factory OnlineChannel.fromJson(Map<String, dynamic> json) => OnlineChannel(
        count: json['count'] as int,
        latestRound: json['latestRound'] as int,
        byMethod: Map<String, int>.from(json['byMethod'] as Map),
      );
}

/// store-ranking.json 전체.
class Ranking {
  const Ranking({required this.online, required this.stores});

  /// 온라인 판매 이전 자료만 있으면 null이다.
  final OnlineChannel? online;

  /// 실물 매장만. 배출 횟수 내림차순.
  final List<StoreRank> stores;

  factory Ranking.fromJson(Map<String, dynamic> json) {
    final online = json['online'];
    return Ranking(
      online: online == null
          ? null
          : OnlineChannel.fromJson(online as Map<String, dynamic>),
      stores: [
        for (final s in json['stores'] as List)
          StoreRank.fromJson(s as Map<String, dynamic>)
      ],
    );
  }

}
