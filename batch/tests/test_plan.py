from lotto.client import plan_rounds

# API는 srchLtEpsd=N 하나로 N-5 ~ N+4 (10회차)를 돌려준다 (2026-08-06 실측).
# 따라서 6, 16, 26… 을 요청하면 1-10, 11-20, 21-30… 이 정확히 맞아떨어진다.


def test_single_request_covers_the_first_ten_rounds():
    assert plan_rounds(10) == [6]


def test_two_requests_cover_twenty_rounds():
    assert plan_rounds(20) == [6, 16]


def test_partial_window_still_gets_a_request():
    assert plan_rounds(15) == [6, 16]


def test_every_round_up_to_latest_is_covered():
    latest = 1235
    covered = set()
    for n in plan_rounds(latest):
        covered.update(range(n - 5, n + 5))

    assert set(range(1, latest + 1)) <= covered
