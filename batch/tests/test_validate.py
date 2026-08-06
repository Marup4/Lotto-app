from lotto.validate import validate


def draw(round_no, auto=1, manual=0, semi=0, winners=None):
    return {
        "round": round_no, "date": "2025-01-01",
        "numbers": [1, 2, 3, 4, 5, 6], "bonus": 7,
        "firstWinners": auto + manual + semi if winners is None else winners,
        "firstAmount": 1, "totalSales": 1,
        "winAuto": auto, "winManual": manual, "winSemi": semi,
    }


def store(round_no, shop_id="A"):
    return {
        "round": round_no, "shopId": shop_id, "name": "가게", "address": "주소",
        "sido": "서울", "sigungu": "강남구", "method": "자동",
        "tel": None, "lat": 0.0, "lon": 0.0,
    }


def test_no_problems_for_a_healthy_dataset():
    draws = [draw(1), draw(2)]
    stores = [store(1), store(2)]

    assert validate(draws, stores, previous_latest=1) == []


def test_empty_draws_is_a_problem():
    # 성공으로 끝나고 빈 파일을 배포하는 게 최악이다 (계획서 5-1)
    problems = validate([], [], previous_latest=None)

    assert any("당첨번호" in p for p in problems)


def test_missing_round_in_the_middle_is_a_problem():
    draws = [draw(1), draw(3)]

    problems = validate(draws, [store(1), store(3)], previous_latest=None)

    assert any("2" in p and "누락" in p for p in problems)


def test_latest_round_going_backwards_is_a_problem():
    draws = [draw(1), draw(2)]

    problems = validate(draws, [store(1), store(2)], previous_latest=5)

    assert any("후퇴" in p for p in problems)


def test_same_latest_round_as_before_is_not_a_problem():
    # 추첨 전에 배치가 돌면 최신 회차가 그대로일 수 있다. 실패가 아니다.
    draws = [draw(1), draw(2)]

    assert validate(draws, [store(1), store(2)], previous_latest=2) == []


def test_method_breakdown_not_matching_winner_count_is_a_problem():
    # winType 합 == 1등 당첨자 수 (262회차 이후 성립, 2026-08-06 실측)
    draws = [draw(300, auto=5, manual=0, semi=0, winners=9)]

    problems = validate(draws, [store(300)], previous_latest=None)

    assert any("300" in p and "자동/수동" in p for p in problems)


def test_round_with_winners_but_no_stores_is_a_problem():
    draws = [draw(300, auto=5)]

    problems = validate(draws, [], previous_latest=None)

    assert any("300" in p and "판매점" in p for p in problems)


def test_missing_tail_rounds_are_a_problem():
    # 앵커가 최신 회차를 넘어가면 API가 빈 배열을 주고 꼬리가 잘린다.
    # 중간 누락만 보는 검사로는 이걸 못 잡는다 (실제로 못 잡았다).
    draws = [draw(r) for r in range(1, 1231)]

    problems = validate(draws, [store(r) for r in range(1, 1231)],
                        previous_latest=None, latest=1235)

    assert any("1235" in p and "1230" in p for p in problems)


def test_no_problem_when_collection_reaches_the_latest_round():
    draws = [draw(1), draw(2)]

    assert validate(draws, [store(1), store(2)],
                    previous_latest=None, latest=2) == []


def test_store_completeness_is_not_checked_during_a_partial_collection():
    # 나눠 받는 중에는 아직 안 받은 회차가 당연히 비어 있다.
    # 이걸 실패로 잡으면 백필을 끝낼 수 없다.
    draws = [draw(300, auto=5), draw(301, auto=3)]

    problems = validate(draws, [store(300)], previous_latest=None,
                        stores_complete=False)

    assert problems == []


def test_round_with_zero_winners_needs_no_stores():
    # 289·295회처럼 1등이 0명인 회차는 판매점도 0건이 정상이다
    draws = [draw(295, auto=0, manual=0, semi=0, winners=0)]

    assert validate(draws, [], previous_latest=None) == []
