from lotto.ranking import build_ranking


def store(round_no, shop_id, name="가게", method="자동", address="서울 강남구 어디로 1"):
    return {
        "round": round_no, "shopId": shop_id, "name": name, "address": address,
        "sido": "서울", "sigungu": "강남구", "method": method,
        "tel": None, "lat": 0.0, "lon": 0.0,
    }


def test_ranks_shops_by_first_prize_count_descending():
    stores = [
        store(1, "A"), store(2, "A"), store(3, "A"),
        store(1, "B"), store(2, "B"),
        store(1, "C"),
    ]

    ranking = build_ranking(stores, limit=10)

    assert [(r["shopId"], r["count"]) for r in ranking] == [("A", 3), ("B", 2), ("C", 1)]


def test_reports_most_recent_round_and_method_breakdown():
    stores = [
        store(10, "A", method="자동"),
        store(45, "A", method="수동"),
        store(30, "A", method="자동"),
    ]

    top = build_ranking(stores, limit=10)[0]

    assert top["latestRound"] == 45
    assert top["byMethod"] == {"자동": 2, "수동": 1}


def test_uses_the_name_from_the_most_recent_win():
    # 상호가 바뀐 매장 — 최신 표기를 보여줘야 한다
    stores = [
        store(10, "A", name="옛날복권방", address="서울 강남구 옛길 1"),
        store(80, "A", name="새이름로또", address="서울 강남구 새길 2"),
    ]

    top = build_ranking(stores, limit=10)[0]

    assert top["name"] == "새이름로또"
    assert top["address"] == "서울 강남구 새길 2"


def test_limit_truncates_to_top_n():
    stores = [store(1, chr(ord("A") + i)) for i in range(10)]

    assert len(build_ranking(stores, limit=3)) == 3


def test_ties_are_broken_by_most_recent_round():
    stores = [store(5, "OLD"), store(99, "NEW")]

    assert [r["shopId"] for r in build_ranking(stores, limit=10)] == ["NEW", "OLD"]
