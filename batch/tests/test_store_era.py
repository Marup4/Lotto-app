"""판매점 데이터가 존재하는 회차 구간에 대한 규칙.

동행복권은 261회차 이하의 1등 판매점을 공개하지 않는다 (2026-08-06 실측).
262회차(2007-12-08)부터 데이터가 있고, 그 이후로는 빠짐없이 존재한다.
자동/수동(winType) 경계와 같은 회차다.
"""
from lotto.collect import rounds_needing_stores
from lotto.store_era import STORE_DATA_FIRST_ROUND, has_store_data
from lotto.validate import validate

from test_validate import draw, store


def test_boundary_is_round_262():
    assert STORE_DATA_FIRST_ROUND == 262
    assert not has_store_data(261)
    assert has_store_data(262)


class TestValidate:
    def test_missing_stores_before_the_boundary_are_not_a_problem(self):
        # 250개 회차가 여기 걸린다. 오탐이면 배치가 영원히 exit 1 한다.
        draws = [draw(260, auto=5), draw(261, auto=3)]

        assert validate(draws, [], previous_latest=None) == []

    def test_missing_stores_after_the_boundary_are_still_a_problem(self):
        draws = [draw(262, auto=2)]

        problems = validate(draws, [], previous_latest=None)

        assert any("262" in p and "판매점" in p for p in problems)


class TestCollect:
    def test_rounds_before_the_boundary_are_never_requested(self):
        # 항상 빈 응답이 돌아온다. 요청하면 IP 차단 예산만 낭비한다.
        draws = {d["round"]: d for d in [draw(100, auto=5), draw(300, auto=2)]}

        assert rounds_needing_stores(draws, cached=set()) == [300]

    def test_cached_rounds_are_not_requested_again(self):
        draws = {d["round"]: d for d in [draw(300, auto=2), draw(301, auto=1)]}

        assert rounds_needing_stores(draws, cached={300}) == [301]

    def test_rounds_without_any_first_prize_winner_are_not_requested(self):
        # 289·295회처럼 1등이 0명인 회차가 실제로 있다
        draws = {d["round"]: d for d in [draw(295, winners=0), draw(296, auto=1)]}

        assert rounds_needing_stores(draws, cached=set()) == [296]

    def test_newest_rounds_come_first(self):
        # 사용자가 보는 것은 최근 회차다. 백필을 도중에 멈춰도
        # 최근 회차부터 쓸 수 있어야 한다.
        draws = {d["round"]: d for d in [draw(300), draw(500), draw(400)]}

        assert rounds_needing_stores(draws, cached=set()) == [500, 400, 300]
