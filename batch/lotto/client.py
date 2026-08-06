"""동행복권 신규 JSON API 클라이언트 (2026-08-06 실측 기준).

구 엔드포인트(common.do / store.do)는 사이트 개편으로 폐기됐다.
자세한 배경은 계획서 부록 A와 README 참조.

⚠️ 이 서버는 연속 요청에 민감하다. 0.5초 간격으로 600회 남짓 요청하자
   IP가 차단됐다(2026-08-06 실측). 전 회차 최초 수집처럼 요청이 많은
   작업은 delay를 넉넉히 주고, 가능하면 여러 번에 나눠 받는다.
   주간 증분 갱신은 요청이 1~2회뿐이라 이 문제와 무관하다.
"""
import random
import time

import requests

BASE = "https://www.dhlottery.co.kr"

# API는 srchLtEpsd=N 하나로 N-5 ~ N+4 (10회차)를 돌려준다.
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

NETWORK_ERRORS = (requests.exceptions.ConnectionError,
                  requests.exceptions.Timeout)


class SiteUnreachable(RuntimeError):
    """재시도를 다 쓰고도 동행복권에 닿지 못했다."""


def plan_rounds(latest):
    """전 회차를 덮는 최소한의 srchLtEpsd 목록.

    6, 16, 26… 을 요청하면 1-10, 11-20, 21-30… 이 정확히 맞아떨어진다.
    1,235회차 기준 124회 요청이면 전 회차가 채워진다.
    """
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

    MAX_ATTEMPTS = 5

    def __init__(self, delay=1.0, session=None, backoff=2.0):
        """delay: 요청 간 기본 간격(초). 실제로는 여기에 지터가 더해진다."""
        self.delay = delay
        self.backoff = backoff
        if session is not None:       # 테스트용 주입
            self.session = session
            return
        self.session = requests.Session()
        self.session.headers.update(HEADERS)
        self._open_session_with_retry()

    # ---- 세션 --------------------------------------------------------

    def _open_session(self):
        """DHJSESSIONID / WMONID 확보. 이게 없으면 조회 API가 동작하지 않는다."""
        self.session.get(f"{BASE}/lt645/result", timeout=30).raise_for_status()

    def _open_session_with_retry(self):
        """최초 접속 실패는 흔한 일시 장애일 수도, IP 차단일 수도 있다.

        몇 번 물러섰다 다시 시도해보고, 그래도 안 되면 원인을 짚어주고 죽는다.
        스택트레이스만 뱉으면 무인 운영 중에 원인 파악이 어렵다.
        """
        for attempt in range(1, self.MAX_ATTEMPTS + 1):
            try:
                self._open_session()
                return
            except NETWORK_ERRORS as e:
                if attempt == self.MAX_ATTEMPTS:
                    raise SiteUnreachable(
                        "동행복권에 접속하지 못했다. 사이트 장애이거나, "
                        "직전에 요청을 너무 촘촘히 보내 IP가 차단됐을 수 있다. "
                        "잠시 뒤 --delay 를 올려 다시 시도할 것."
                    ) from e
                wait = self.backoff * attempt
                print(f"  접속 실패 — {wait:.0f}초 후 재시도 "
                      f"{attempt}/{self.MAX_ATTEMPTS - 1}", flush=True)
                time.sleep(wait)

    # ---- 요청 --------------------------------------------------------

    def _pause(self):
        """요청 간 간격 + 지터.

        일정한 간격으로 두드리는 쪽이 오히려 자동화로 잡히기 쉽다.
        """
        if self.delay:
            time.sleep(self.delay * random.uniform(0.8, 1.3))

    def _get(self, path, params):
        """연결이 끊기면 재접속 후 재시도한다.

        긴 수집 도중 서버가 연결을 끊는 일이 실제로 있다. 한 번의 리셋으로
        배치 전체가 죽으면 주간 갱신이 멈춘다.
        """
        for attempt in range(1, self.MAX_ATTEMPTS + 1):
            self._pause()
            try:
                r = self.session.get(f"{BASE}{path}", params=params, timeout=30)
                r.raise_for_status()
                return r.json()["data"]
            except NETWORK_ERRORS as e:
                if attempt == self.MAX_ATTEMPTS:
                    raise
                wait = self.backoff * attempt
                print(f"    연결 끊김({e.__class__.__name__}) — "
                      f"{wait:.0f}초 후 재시도 {attempt}/{self.MAX_ATTEMPTS - 1}",
                      flush=True)
                time.sleep(wait)
                try:
                    self._open_session()
                except Exception:
                    pass          # 재접속 실패해도 다음 시도에서 다시 해본다

    # ---- 조회 --------------------------------------------------------

    def draws_around(self, round_no):
        """N-5 ~ N+4 회차의 당첨번호를 한 번에 받는다."""
        data = self._get("/lt645/selectPstLt645InfoNew.do",
                         {"srchDir": "center", "srchLtEpsd": str(round_no)})
        return data.get("list") or []

    def first_prize_stores(self, round_no):
        """해당 회차의 1등 판매점 전체.

        회차당 10~20곳이라 페이지네이션이 필요 없다.
        응답에 ltShpId(매장 고유 ID)와 자동/수동 구분이 함께 온다.
        """
        data = self._get("/wnprchsplcsrch/selectLtWnShp.do",
                         {"srchWnShpRnk": "1", "srchLtEpsd": str(round_no),
                          "srchShpLctn": ""})
        return data.get("list") or []

    def latest_round(self, hint=1235):
        """존재하는 최대 회차를 이분 탐색한다.

        회차는 단조 증가하므로 hint 이상만 살펴보면 된다.
        hint가 맞으면 몇 번의 요청으로 끝난다.
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
