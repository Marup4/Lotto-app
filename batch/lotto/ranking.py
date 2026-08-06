"""역대 1등 배출 매장 랭킹 (F7).

v0.2가 계획했던 매장명·주소 문자열 정규화는 필요 없다.
API가 `ltShpId`라는 매장 고유 ID를 주므로 그것으로 바로 묶는다.
"""


def build_ranking(stores, limit):
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

    ranked = sorted(by_shop.values(), key=lambda a: (-a["count"], -a["latestRound"]))
    return ranked[:limit]
