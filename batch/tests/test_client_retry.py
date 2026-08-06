import pytest
import requests

from lotto.client import DhLottery


class FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


class FlakySession:
    """지정한 횟수만큼 연결을 끊고, 그 다음부터는 정상 응답한다."""

    def __init__(self, failures, payload=None):
        self.failures = failures
        self.payload = payload or {"data": {"list": [{"ok": True}]}}
        self.headers = {}
        self.attempts = 0

    def get(self, url, **kwargs):
        self.attempts += 1
        if self.attempts <= self.failures:
            raise requests.exceptions.ConnectionError("Connection aborted.")
        return FakeResponse(self.payload)


def client(session):
    return DhLottery(delay=0, session=session, backoff=0)


def test_recovers_from_a_transient_connection_reset():
    # 실제로 1,200회 연속 요청 중 서버가 연결을 끊는다 (2026-08-06 관측).
    # 한 번 끊겼다고 배치 전체가 죽으면 안 된다.
    session = FlakySession(failures=2)

    result = client(session).first_prize_stores(1235)

    assert result == [{"ok": True}]


def test_gives_up_after_exhausting_retries():
    session = FlakySession(failures=99)

    with pytest.raises(requests.exceptions.ConnectionError):
        client(session).first_prize_stores(1235)


def test_does_not_retry_forever():
    session = FlakySession(failures=99)

    with pytest.raises(requests.exceptions.ConnectionError):
        client(session).first_prize_stores(1235)

    # 데이터 요청 MAX_ATTEMPTS회 + 그 사이 재접속 시도까지 포함해 유한하게 끝난다
    assert session.attempts <= 2 * DhLottery.MAX_ATTEMPTS
