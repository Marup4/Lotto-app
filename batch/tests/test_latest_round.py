"""latest_round()는 존재하지 않는 회차를 반환해선 안 된다.

API는 srchLtEpsd=N 에 N-5 ~ N+4 창을 돌려준다. 응답이 비어 있지 않다고
해서 N 자신이 존재한다는 뜻이 아니다 — 창이 겹쳐 앞쪽 회차만 걸릴 수 있다.
"""
from lotto.client import DhLottery


class FakeResponse:
    def __init__(self, payload):
        self._p = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._p


class FakeApi:
    """실제 API 흉내: 존재하는 회차만 창 안에서 돌려준다."""

    def __init__(self, latest):
        self.latest = latest
        self.headers = {}
        self.calls = 0

    def get(self, url, params=None, **kwargs):
        self.calls += 1
        n = int(params["srchLtEpsd"])
        rounds = [r for r in range(n - 5, n + 5) if 1 <= r <= self.latest]
        return FakeResponse({"data": {"list": [{"ltEpsd": r} for r in rounds]}})


def find(latest, hint):
    api = FakeApi(latest)
    got = DhLottery(delay=0, session=api, backoff=0).latest_round(hint=hint)
    return got, api.calls


def test_hint_matches_the_actual_latest():
    assert find(1235, 1235)[0] == 1235


def test_new_rounds_appeared_since_the_hint():
    assert find(1241, 1235)[0] == 1241


def test_hint_is_ahead_of_the_actual_latest():
    # 창이 겹치는 1~5회 구간. 예전에는 존재하지 않는 1235를 반환했다.
    for actual in (1230, 1231, 1234):
        got, _ = find(actual, 1235)
        assert got == actual, f"latest={actual} 인데 {got} 를 반환했다"


def test_hint_far_ahead_still_finds_the_truth():
    assert find(1229, 1235)[0] == 1229


def test_does_not_walk_from_round_one_when_the_hint_is_slightly_off():
    # 창 밖으로 조금 벗어났다고 1회차부터 훑으면 요청이 폭증해
    # IP 차단 위험이 커진다.
    _, calls = find(1229, 1235)

    assert calls < 30, f"요청이 {calls}회나 나갔다"
