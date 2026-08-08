"""집계 전 회차가 그 상태로 굳어버리는 사고를 막는 테스트.

토요일 밤에 받은 회차는 당첨번호만 있고 당첨금·판매점은 0이다.
그걸 '이미 가진 회차'로 보고 다시 받지 않으면 영원히 0으로 남는다.
그러면 판매점도 영영 안 채워지고 화면에는 '집계 중'이 계속 뜬다.
"""
from lotto.collect import collect_draws


def raw_draw(round_no, first_winners=9, total_sales=115445069000):
    """API 원본 형식. parse_draw가 소비한다."""
    return {
        "ltEpsd": round_no,
        "ltRflYmd": "20260808",
        **{f"tm{i}WnNo": i for i in range(1, 7)},
        "bnsWnNo": 7,
        "rnk1WnNope": first_winners,
        "rnk1WnAmt": 2000000000 if first_winners else 0,
        "wholEpsdSumNtslAmt": total_sales,
        "winType1": first_winners,
        "winType2": 0,
        "winType3": 0,
    }


def parsed(round_no, first_winners=9, total_sales=115445069000):
    """draws.json에 저장돼 있는 형식."""
    return {
        "round": round_no, "date": "2026-08-08",
        "numbers": [1, 2, 3, 4, 5, 6], "bonus": 7,
        "firstWinners": first_winners,
        "firstAmount": 2000000000 if first_winners else 0,
        "totalSales": total_sales,
        "winAuto": first_winners, "winManual": 0, "winSemi": 0,
    }


class FakeApi:
    """집계가 끝난 값을 돌려준다. 요청한 앵커를 기록한다."""

    def __init__(self, rounds):
        self.rounds = rounds
        self.asked = []

    def draws_around(self, anchor):
        self.asked.append(anchor)
        return [raw_draw(r) for r in self.rounds
                if anchor - 5 <= r < anchor + 5]


def test_refetches_a_round_that_is_not_settled_yet():
    # 토요일 밤에 받아둔 1236회차: 당첨번호만 있고 집계는 전부 0이다
    known = {r: parsed(r) for r in range(1, 1236)}
    known[1236] = parsed(1236, first_winners=0, total_sales=0)
    api = FakeApi(range(1, 1237))

    draws = collect_draws(api, 1236, known)

    assert draws[1236]["firstWinners"] == 9, "일요일 실행이 값을 채워야 한다"
    assert draws[1236]["totalSales"] > 0


def test_does_not_refetch_when_everything_is_settled():
    # 요청이 늘면 IP 차단 위험이 커진다. 평소에는 한 번도 부르지 않아야 한다
    known = {r: parsed(r) for r in range(1, 1236)}
    api = FakeApi(range(1, 1236))

    collect_draws(api, 1235, known)

    assert api.asked == []


def test_still_fetches_missing_rounds():
    known = {r: parsed(r) for r in range(1, 1230)}
    api = FakeApi(range(1, 1236))

    draws = collect_draws(api, 1235, known)

    assert sorted(draws) == list(range(1, 1236))


def test_a_settled_round_without_winners_is_not_refetched():
    # 289·295회는 1등이 진짜 0명이다. 판매금액이 있으므로 확정된 값이며
    # 매번 다시 받으면 요청만 낭비한다
    known = {r: parsed(r) for r in range(1, 1236)}
    known[289] = parsed(289, first_winners=0, total_sales=39406643000)
    api = FakeApi(range(1, 1236))

    collect_draws(api, 1235, known)

    assert api.asked == []
