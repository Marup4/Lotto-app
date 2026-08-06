from lotto.stats import number_frequency, drought, method_totals


def draw(round_no, numbers, bonus=45, auto=0, manual=0, semi=0, winners=None):
    return {
        "round": round_no, "date": "2025-01-01", "numbers": numbers, "bonus": bonus,
        "firstWinners": auto + manual + semi if winners is None else winners,
        "firstAmount": 1, "totalSales": 1,
        "winAuto": auto, "winManual": manual, "winSemi": semi,
    }


def test_number_frequency_counts_every_number_from_1_to_45():
    freq = number_frequency([draw(1, [1, 2, 3, 4, 5, 6])])

    assert len(freq) == 45
    assert freq[1] == 1
    assert freq[45] == 0


def test_number_frequency_excludes_the_bonus_ball():
    # 보너스는 당첨번호 6개와 성격이 다르므로 빈도에 넣지 않는다
    freq = number_frequency([draw(1, [1, 2, 3, 4, 5, 6], bonus=7)])

    assert freq[7] == 0


def test_number_frequency_accumulates_across_draws():
    freq = number_frequency([
        draw(1, [1, 2, 3, 4, 5, 6]),
        draw(2, [1, 2, 3, 7, 8, 9]),
    ])

    assert freq[1] == 2
    assert freq[7] == 1


def test_drought_counts_rounds_since_the_number_last_appeared():
    draws = [
        draw(10, [1, 2, 3, 4, 5, 6]),
        draw(11, [7, 8, 9, 10, 11, 12]),
        draw(12, [7, 8, 9, 10, 11, 12]),
    ]

    d = drought(draws)

    assert d[7] == 0    # 최신 회차에 나왔다
    assert d[1] == 2    # 10회차 이후 2회차 동안 안 나왔다


def test_drought_is_independent_of_input_order():
    ordered = [draw(10, [1, 2, 3, 4, 5, 6]), draw(11, [7, 8, 9, 10, 11, 12])]
    shuffled = [ordered[1], ordered[0]]

    assert drought(shuffled) == drought(ordered)


def test_drought_marks_never_drawn_numbers_with_the_total_round_count():
    d = drought([draw(1, [1, 2, 3, 4, 5, 6]), draw(2, [1, 2, 3, 4, 5, 6])])

    assert d[45] == 2


def test_method_totals_sums_first_prize_auto_manual_semi():
    totals = method_totals([
        draw(300, [1, 2, 3, 4, 5, 6], auto=12, manual=2, semi=1),
        draw(301, [1, 2, 3, 4, 5, 6], auto=7, manual=2, semi=0),
    ])

    assert totals["자동"] == 19
    assert totals["수동"] == 4
    assert totals["반자동"] == 1


def test_method_totals_ignores_rounds_where_the_api_has_no_method_data():
    # 261회차 이하는 winType이 전부 0으로 비어 있다 (2026-08-06 실측).
    # 그대로 합산하면 자동 비율이 인위적으로 낮아진다.
    totals = method_totals([
        draw(200, [1, 2, 3, 4, 5, 6], auto=0, manual=0, semi=0, winners=8),
        draw(300, [1, 2, 3, 4, 5, 6], auto=12, manual=2, semi=1),
    ])

    assert totals["자동"] == 12
    assert totals["fromRound"] == 300


def test_method_totals_keeps_genuine_zero_winner_rounds_inside_the_covered_range():
    # 289·295회처럼 1등 당첨자가 실제로 0명인 회차가 있다.
    # 커버 구간이 시작된 뒤라면 결측이 아니라 정상 회차로 세어야 한다.
    totals = method_totals([
        draw(290, [1, 2, 3, 4, 5, 6], auto=13, manual=0, semi=0),
        draw(295, [1, 2, 3, 4, 5, 6], auto=0, manual=0, semi=0, winners=0),
        draw(296, [1, 2, 3, 4, 5, 6], auto=8, manual=0, semi=0),
    ])

    assert totals["fromRound"] == 290
    assert totals["coveredRounds"] == 3


def test_method_totals_excludes_zero_winner_rounds_from_the_missing_data_era():
    # 1회차는 1등 당첨자가 0명이다. 회차 단독으로 보면 '정상 0당첨'과
    # 구분되지 않지만, 실제로는 winType이 존재하지 않던 시대다.
    # 커버리지는 데이터가 처음 등장한 회차부터의 연속 구간이어야 한다.
    totals = method_totals([
        draw(1, [1, 2, 3, 4, 5, 6], winners=0),
        draw(200, [1, 2, 3, 4, 5, 6], winners=8),
        draw(262, [1, 2, 3, 4, 5, 6], auto=2),
        draw(289, [1, 2, 3, 4, 5, 6], winners=0),
    ])

    assert totals["fromRound"] == 262
    assert totals["coveredRounds"] == 2
