"""동행복권 API 응답을 앱이 소비할 스키마로 변환한다."""


def parse_store(raw, round_no):
    return {
        "round": round_no,
        "shopId": raw["ltShpId"],
        # 실제로 매장명이 비어 있는 레코드가 있다 (578회). 앱에 "null"이
        # 찍히지 않도록 여기서 막는다.
        "name": raw["shpNm"] or "이름 미상",
        "address": " ".join(raw["shpAddr"].split()),
        # 지역 필터가 null을 만나면 드롭다운이 깨진다 (572회 시군구 결측).
        "sido": raw["tm1ShpLctnAddr"] or "",
        "sigungu": raw["tm2ShpLctnAddr"] or "",
        "method": raw["atmtPsvYnTxt"],
        "tel": raw["shpTelno"],
        "lat": raw["shpLat"],
        "lon": raw["shpLot"],
    }


def parse_draw(raw):
    ymd = raw["ltRflYmd"]
    return {
        "round": raw["ltEpsd"],
        "date": f"{ymd[0:4]}-{ymd[4:6]}-{ymd[6:8]}",
        "numbers": [raw[f"tm{i}WnNo"] for i in range(1, 7)],
        "bonus": raw["bnsWnNo"],
        "firstWinners": raw["rnk1WnNope"],
        "firstAmount": raw["rnk1WnAmt"],
        # 총 판매금액은 wholEpsdSumNtslAmt 다.
        # rlvtEpsdSumNtslAmt는 1~5등 당첨금 총합(= 판매액의 50%)이라
        # 그걸 쓰면 화면에 실제의 절반이 찍힌다.
        "totalSales": raw["wholEpsdSumNtslAmt"],
        "winAuto": raw["winType1"],
        "winManual": raw["winType2"],
        "winSemi": raw["winType3"],
    }
