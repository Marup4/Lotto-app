from lotto.stats import build_stats_payload


def draw(round_no, numbers, auto=1, manual=0, semi=0, winners=None):
    return {
        "round": round_no, "date": "2025-01-01", "numbers": numbers, "bonus": 45,
        "firstWinners": auto + manual + semi if winners is None else winners,
        "firstAmount": 1, "totalSales": 1,
        "winAuto": auto, "winManual": manual, "winSemi": semi,
    }


def test_number_keys_are_strings_so_json_round_trips_cleanly():
    payload = build_stats_payload([draw(1, [1, 2, 3, 4, 5, 6])])

    assert "1" in payload["frequency"]
    assert 1 not in payload["frequency"]


def test_payload_discloses_the_round_method_data_starts_from():
    # 앱은 "262회차 이후 기준"이라고 고지해야 한다
    payload = build_stats_payload([
        draw(200, [1, 2, 3, 4, 5, 6], auto=0, manual=0, semi=0, winners=8),
        draw(262, [1, 2, 3, 4, 5, 6], auto=2),
    ])

    assert payload["method"]["fromRound"] == 262


def test_recent_frequency_windows_are_independent_of_input_order():
    ordered = [draw(n, [1, 2, 3, 4, 5, 6]) for n in range(1, 21)]
    ordered[-1] = draw(20, [7, 8, 9, 10, 11, 12])

    payload = build_stats_payload(list(reversed(ordered)))

    assert payload["recentFrequency"]["10"]["7"] == 1
    assert payload["latestRound"] == 20
