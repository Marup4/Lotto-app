"""실제 데이터에 섞여 있는 결측값 방어.

578회 매장명 null, 572회 시군구 null 이 실측으로 확인됐다.
그대로 통과시키면 앱 화면에 "null"이 찍힌다.
"""
from lotto.parse import parse_store

BASE = {
    "ltShpId": "11101001",
    "shpNm": "가게",
    "shpAddr": "서울 서초구 반포동 19-1번지",
    "tm1ShpLctnAddr": "서울",
    "tm2ShpLctnAddr": "서초구",
    "atmtPsvYnTxt": "수동",
    "shpTelno": None,
    "shpLat": 37.5,
    "shpLot": 127.0,
}


def test_missing_store_name_falls_back_to_a_readable_label():
    raw = {**BASE, "shpNm": None}

    assert parse_store(raw, round_no=578)["name"] == "이름 미상"


def test_missing_sigungu_becomes_empty_string_not_null():
    # 지역 필터가 null을 만나면 드롭다운이 깨진다
    raw = {**BASE, "tm2ShpLctnAddr": None}

    assert parse_store(raw, round_no=572)["sigungu"] == ""


def test_normal_records_are_untouched():
    parsed = parse_store(BASE, round_no=1235)

    assert parsed["name"] == "가게"
    assert parsed["sigungu"] == "서초구"


def test_missing_address_does_not_crash_the_batch():
    # 이름·시군구가 실제로 null이었으므로 주소도 그럴 수 있다고 본다.
    # 막지 않으면 AttributeError로 배치 전체가 죽는다 — 한 회차 때문에
    # 그 주의 갱신이 통째로 멈춘다.
    raw = {**BASE, "shpAddr": None}

    assert parse_store(raw, round_no=1235)["address"] == ""
