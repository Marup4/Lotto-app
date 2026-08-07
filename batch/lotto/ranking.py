"""역대 1등 배출 매장 랭킹 (F7).

v0.2가 계획했던 매장명·주소 문자열 정규화는 필요 없다.
API가 `ltShpId`라는 매장 고유 ID를 주므로 그것으로 바로 묶는다.

동행복권 온라인 구매는 랭킹에서 빼고 따로 낸다. 이유는 아래 ONLINE_* 참조.
"""

# 동행복권 인터넷 복권판매사이트. 실물 매장이 아니다.
#
# 2026-08-07 실측: 1등 118회로 압도적 1위이고 2위(51회)의 두 배가 넘는다.
# 그대로 두면 '찾아갈 수 있는 명당' 목록이라는 성격이 무너진다.
# 지도에 찍을 수도, 찾아갈 수도 없는 곳이다.
#
# 다만 온라인으로 얼마나 나오는지 궁금해하는 사람이 있으므로 버리지는 않고
# 목록 위에 따로 표기한다 (사용자 결정, 2026-08-07).
ONLINE_SHOP_ID = "51100000"
ONLINE_ADDRESS_MARK = "dhlottery"


def is_online(store):
    """온라인 구매분인가.

    ID를 먼저 본다 — 이름·주소는 표기가 바뀔 수 있는 화면용 문자열이다.
    주소도 함께 보는 이유는 ID가 재발급되면 온라인이 랭킹 1위로 올라와
    목록이 통째로 뒤집히기 때문이다. 조용히 깨지면 알아채기 어렵다.
    """
    return (store["shopId"] == ONLINE_SHOP_ID
            or ONLINE_ADDRESS_MARK in (store.get("address") or ""))


def _aggregate(stores):
    """매장별로 1등 배출 횟수를 묶는다."""
    by_shop = {}
    for s in stores:
        agg = by_shop.setdefault(s["shopId"], {
            "shopId": s["shopId"],
            "count": 0,
            "latestRound": -1,
            "byMethod": {},
        })
        agg["count"] += 1
        agg["byMethod"][s["method"]] = agg["byMethod"].get(s["method"], 0) + 1
        # 상호·주소는 가장 최근 배출 시점의 표기를 따른다
        if s["round"] > agg["latestRound"]:
            agg["latestRound"] = s["round"]
            agg["name"] = s["name"]
            agg["address"] = s["address"]
            agg["sido"] = s["sido"]
            agg["sigungu"] = s["sigungu"]
            # 지금 화면에는 안 쓴다. 나중에 지도를 붙일 때 배치를 다시
            # 손대지 않아도 되도록 미리 담아둔다 — 50건이라 무게가 없다.
            agg["lat"] = s["lat"]
            agg["lon"] = s["lon"]
    return by_shop


def build_ranking(stores, limit):
    """실물 매장 랭킹 TOP N. 온라인 구매분은 들어가지 않는다."""
    by_shop = _aggregate(s for s in stores if not is_online(s))
    ranked = sorted(by_shop.values(), key=lambda a: (-a["count"], -a["latestRound"]))
    return ranked[:limit]


def build_online(stores):
    """온라인 구매분 집계. 해당 건이 없으면 None."""
    by_shop = _aggregate(s for s in stores if is_online(s))
    if not by_shop:
        return None
    # ID가 재발급된 경우까지 한 덩어리로 본다 — 사용자에겐 같은 '온라인'이다.
    merged = {"count": 0, "latestRound": -1, "byMethod": {}}
    for agg in by_shop.values():
        merged["count"] += agg["count"]
        for method, n in agg["byMethod"].items():
            merged["byMethod"][method] = merged["byMethod"].get(method, 0) + n
        if agg["latestRound"] > merged["latestRound"]:
            merged["latestRound"] = agg["latestRound"]
            merged["name"] = agg["name"]
    return merged


def build_ranking_payload(stores, limit):
    """store-ranking.json의 내용. 온라인과 실물 매장을 갈라 담는다."""
    stores = list(stores)
    return {
        "online": build_online(stores),
        "stores": build_ranking(stores, limit),
    }
