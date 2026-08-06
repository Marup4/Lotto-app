"""동행복권 API 응답을 앱이 소비할 스키마로 변환한다."""


def parse_store(raw, round_no):
    return {
        "round": round_no,
        "shopId": raw["ltShpId"],
        "name": raw["shpNm"],
        "address": " ".join(raw["shpAddr"].split()),
        "sido": raw["tm1ShpLctnAddr"],
        "sigungu": raw["tm2ShpLctnAddr"],
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
        "totalSales": raw["rlvtEpsdSumNtslAmt"],
        "winAuto": raw["winType1"],
        "winManual": raw["winType2"],
        "winSemi": raw["winType3"],
    }
