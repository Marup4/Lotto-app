"""동행복권 신규 JSON API 클라이언트 (2026-08-06 실측 기준).

구 엔드포인트(common.do / store.do)는 사이트 개편으로 폐기됐다.
자세한 배경은 계획서 부록 A 참조.
"""

import time

import requests

BASE = "https://www.dhlottery.co.kr"
WINDOW = 10

# 기본 헤더로는 차단될 수 있다. 브라우저 UA를 명시한다.
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/130.0 Safari/537.36"
    ),
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "X-Requested-With": "XMLHttpRequest",
    "Referer": f"{BASE}/lt645/result",
}


def plan_rounds(latest):
    """전 회차를 덮는 최소한의 srchLtEpsd 목록."""
    anchors = []
    anchor = WINDOW // 2 + 1          # 6 → 1~10
    while anchor - WINDOW // 2 <= latest:
        anchors.append(anchor)
        anchor += WINDOW
    return anchors


class DhLottery:
    """세션 쿠키를 한 번 받아두고 재사용한다.

    모든 조회 API는 GET + 쿼리스트링이다. POST로 보내면 500이 떨어진다.
    """

    def __init__(self, delay=1.0):
        self.delay = delay
        self.session = requests.Session()
        self.session.headers.update(HEADERS)
        # DHJSESSIONID / WMONID 확보
        self.session.get(f"{BASE}/lt645/result", timeout=30).raise_for_status()

    def _get(self, path, params):
        time.sleep(self.delay)
        r = self.session.get(f"{BASE}{path}", params=params, timeout=30)
        r.raise_for_status()
        return r.json()["data"]

    def draws_around(self, round_no):
        """srchLtEpsd=N 하나로 N-5 ~ N+4 회차를 받는다."""
        data = self._get("/lt645/selectPstLt645InfoNew.do",
                         {"srchDir": "center", "srchLtEpsd": str(round_no)})
        return data.get("list") or []

    def first_prize_stores(self, round_no):
        data = self._get("/wnprchsplcsrch/selectLtWnShp.do",
                         {"srchWnShpRnk": "1", "srchLtEpsd": str(round_no),
                          "srchShpLctn": ""})
        return data.get("list") or []

    def latest_round(self, hint=1235):
        """존재하는 최대 회차를 이분 탐색한다.

        회차 수는 단조 증가하므로 hint 이상만 보면 된다.
        """
        lo = hint if self.draws_around(hint) else 1
        hi = lo
        while self.draws_around(hi + WINDOW):
            hi += WINDOW
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if any(d["ltEpsd"] == mid for d in self.draws_around(mid)):
                lo = mid
            else:
                hi = mid - 1
        return lo
