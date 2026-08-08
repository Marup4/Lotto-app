"""집계 전 회차를 '1등 없음'으로 확정해버리는 사고를 막는 테스트.

추첨 직후에는 당첨번호만 나오고 당첨금·판매점은 나중에 채워진다.
그 사이에 빈 판매점 파일을 캐시로 남기면 다음 실행이 영영 건너뛴다.
"""
import json

import pytest

from lotto import collect, storage
from lotto.collect import collect_stores, is_settled_without_winner


def draw(round_no, first_winners, total_sales):
    return {"round": round_no, "firstWinners": first_winners,
            "totalSales": total_sales}


class FakeApi:
    """요청한 회차를 기록하고, 회차당 판매점 한 곳을 돌려준다."""

    def __init__(self):
        self.asked = []

    def first_prize_stores(self, round_no):
        self.asked.append(round_no)
        return [{"ltShpId": "A", "shpNm": "가게", "shpAddr": "서울 강남구 어디로 1",
                 "tm1ShpLctnAddr": "서울", "tm2ShpLctnAddr": "강남구",
                 "atmtPsvYnTxt": "자동", "shpTelno": None,
                 "shpLat": 37.5, "shpLot": 127.0}]


@pytest.fixture(autouse=True)
def temp_data(tmp_path, monkeypatch):
    """판매점 파일을 임시 폴더에 쓰게 한다 — 실제 data/를 건드리지 않는다."""
    monkeypatch.setattr(storage, "DATA", tmp_path)
    monkeypatch.setattr(collect, "store_path",
                        lambda r: tmp_path / f"{r}.json")
    return tmp_path


def test_just_drawn_round_is_not_cached_as_empty(temp_data):
    # 토요일 밤: 당첨번호는 나왔지만 집계 전이라 1등이 0명으로 보인다
    just_drawn = draw(1236, first_winners=0, total_sales=0)

    collect_stores(FakeApi(), {1236: just_drawn})

    assert not (temp_data / "1236.json").exists(), \
        "빈 파일을 남기면 일요일 실행이 '이미 받았다'며 건너뛴다"


def test_settled_round_without_winner_is_cached_as_empty(temp_data):
    # 289·295회처럼 진짜 1등이 0명인 회차. 다시 물어볼 이유가 없다
    no_winner = draw(289, first_winners=0, total_sales=39406643000)

    collect_stores(FakeApi(), {289: no_winner})

    assert json.loads((temp_data / "289.json").read_text(encoding="utf-8")) == []


def test_round_is_collected_once_settlement_arrives(temp_data):
    api = FakeApi()
    # 토요일: 집계 전 — 건너뛴다
    collect_stores(api, {1236: draw(1236, 0, 0)})
    assert api.asked == []

    # 일요일: 당첨금이 확정됐다 — 이제 받아야 한다
    stores, remaining = collect_stores(api, {1236: draw(1236, 9, 115445069000)})

    assert api.asked == [1236]
    assert len(stores[1236]) == 1
    assert remaining == 0


def test_settled_flag_distinguishes_the_two_zeroes():
    assert is_settled_without_winner(draw(289, 0, 39406643000)) is True
    assert is_settled_without_winner(draw(1236, 0, 0)) is False
    assert is_settled_without_winner(draw(1235, 9, 115445069000)) is False


class EmptyApi:
    """판매점이 아직 공개되지 않아 빈 배열을 돌려주는 상태."""

    def __init__(self):
        self.asked = []

    def first_prize_stores(self, round_no):
        self.asked.append(round_no)
        return []


def test_empty_response_is_not_cached(temp_data):
    # 1등이 9명인데 판매점 목록이 아직 안 올라온 구간이 있다.
    # 빈 파일로 못박으면 validate가 '1등 9명인데 판매점 0건'으로 걸어
    # build가 exit 1 하고, 워크플로의 if: always() 커밋이 그 파일을 올린다.
    # 이후 모든 실행이 캐시를 읽어 같은 자리에서 죽는다 — 손으로 지워야 풀린다.
    settled = draw(1236, first_winners=9, total_sales=115445069000)

    stores, remaining = collect_stores(EmptyApi(), {1236: settled})

    assert not (temp_data / "1236.json").exists()
    assert remaining == 1, "다음 실행이 다시 받도록 남은 것으로 센다"
    assert 1236 not in stores


def test_empty_response_is_retried_next_run(temp_data):
    settled = {1236: draw(1236, 9, 115445069000)}
    collect_stores(EmptyApi(), settled)

    api = FakeApi()
    stores, remaining = collect_stores(api, settled)

    assert api.asked == [1236]
    assert len(stores[1236]) == 1
    assert remaining == 0
