from lotto.parse import parse_draw, parse_store


def test_parse_draw_maps_api_fields_to_app_schema():
    raw = {
        "ltEpsd": 1154,
        "ltRflYmd": "20250111",
        "tm1WnNo": 4, "tm2WnNo": 8, "tm3WnNo": 22,
        "tm4WnNo": 26, "tm5WnNo": 32, "tm6WnNo": 38,
        "bnsWnNo": 27,
        "rnk1WnNope": 15,
        "rnk1WnAmt": 1854965425,
        # rlvt = 1~5등 당첨금 총합, whol = 총 판매금액 (정확히 2배).
        # 로또는 판매액의 50%가 당첨금으로 나간다 — 화면에 쓸 값은 whol이다.
        "rlvtEpsdSumNtslAmt": 57634128500,
        "wholEpsdSumNtslAmt": 115268257000,
        "winType1": 12, "winType2": 2, "winType3": 1,
    }

    assert parse_draw(raw) == {
        "round": 1154,
        "date": "2025-01-11",
        "numbers": [4, 8, 22, 26, 32, 38],
        "bonus": 27,
        "firstWinners": 15,
        "firstAmount": 1854965425,
        "totalSales": 115268257000,
        "winAuto": 12,
        "winManual": 2,
        "winSemi": 1,
    }


def test_parse_store_collapses_ragged_whitespace_in_address():
    # API가 실제로 돌려주는 형태: 내부 연속 공백 + 끝 공백
    raw = {
        "ltShpId": "11190016",
        "shpNm": "미나식품(로또판매점)",
        "shpAddr": "서울 강서구  금낭화로 91-12 ",
        "tm1ShpLctnAddr": "서울",
        "tm2ShpLctnAddr": "강서구",
        "atmtPsvYnTxt": "수동",
        "shpTelno": "02-2664-6793",
        "shpLat": 37.573514,
        "shpLot": 126.81068,
    }

    assert parse_store(raw, round_no=1150) == {
        "round": 1150,
        "shopId": "11190016",
        "name": "미나식품(로또판매점)",
        "address": "서울 강서구 금낭화로 91-12",
        "sido": "서울",
        "sigungu": "강서구",
        "method": "수동",
        "tel": "02-2664-6793",
        "lat": 37.573514,
        "lon": 126.81068,
    }


def test_parse_store_keeps_missing_phone_as_none():
    raw = {
        "ltShpId": "12640196",
        "shpNm": "진우복권",
        "shpAddr": "부산 연제구  월드컵대로 119 204호(연산동)",
        "tm1ShpLctnAddr": "부산",
        "tm2ShpLctnAddr": "연제구",
        "atmtPsvYnTxt": "자동",
        "shpTelno": None,
        "shpLat": 35.184819,
        "shpLot": 129.08207,
    }

    assert parse_store(raw, round_no=1150)["tel"] is None
