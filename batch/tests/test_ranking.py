from lotto.ranking import build_ranking, build_ranking_payload


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


def online(round_no, method="자동"):
    """동행복권 온라인 구매. 실물 매장이 아니다 (2026-08-07 실측 118건)."""
    return {
        "round": round_no, "shopId": "51100000",
        "name": "인터넷 복권판매사이트", "address": "동행복권(dhlottery.co.kr)",
        "sido": "서울", "sigungu": "서초구", "method": method,
        "tel": None, "lat": 0.0, "lon": 0.0,
    }


def test_online_channel_is_kept_out_of_the_store_ranking():
    # 온라인은 2위(51회)의 두 배 넘게 1등을 내므로 그냥 두면 랭킹을 지배한다.
    # '찾아갈 수 있는 명당' 목록이라는 성격이 무너진다.
    stores = [online(1), online(2), online(3), store(4, "A")]

    ranking = build_ranking(stores, limit=10)

    assert [r["shopId"] for r in ranking] == ["A"]


def test_online_channel_is_reported_separately():
    stores = [online(1, "자동"), online(2, "수동"), store(3, "A")]

    payload = build_ranking_payload(stores, limit=10)

    assert payload["online"]["count"] == 2
    assert payload["online"]["byMethod"] == {"자동": 1, "수동": 1}
    assert [r["shopId"] for r in payload["stores"]] == ["A"]


def test_online_is_null_when_absent():
    # 온라인 판매 이전 회차만 모으면 없을 수 있다. 화면이 이걸 보고 갈라야 한다.
    payload = build_ranking_payload([store(1, "A")], limit=10)

    assert payload["online"] is None


def test_online_is_detected_by_address_too():
    # shopId가 재발급되어도 걸러져야 한다 — 랭킹 1위가 통째로 뒤집히는 사고다
    renamed = online(1)
    renamed["shopId"] = "99999999"

    assert build_ranking([renamed, store(2, "A")], limit=10) == \
        build_ranking([store(2, "A")], limit=10)


def test_carries_coordinates_for_a_future_map():
    # 지도는 아직 안 붙였지만 좌표는 원본에 있다. 나중에 배치를 다시
    # 돌리지 않아도 되도록 랭킹에 담아둔다.
    s = store(1, "A")
    s["lat"], s["lon"] = 37.5, 127.0

    top = build_ranking([s], limit=10)[0]

    assert (top["lat"], top["lon"]) == (37.5, 127.0)
