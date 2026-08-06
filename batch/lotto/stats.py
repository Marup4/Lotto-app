"""통계 사전 계산 (F4).

앱은 1,200회차를 순회하지 않는다. 여기서 계산해 stats.json으로 내보낸다.
"""

ALL_NUMBERS = range(1, 46)
RECENT_WINDOWS = (10, 30, 50)


def number_frequency(draws):
    freq = {n: 0 for n in ALL_NUMBERS}
    for d in draws:
        for n in d["numbers"]:
            freq[n] += 1
    return freq


def drought(draws):
    ordered = sorted(draws, key=lambda d: d["round"])
    last_seen = {}
    for i, d in enumerate(ordered):
        for n in d["numbers"]:
            last_seen[n] = i

    total = len(ordered)
    return {n: total - 1 - last_seen[n] if n in last_seen else total
            for n in ALL_NUMBERS}


def method_breakdown_sum(draw):
    return draw["winAuto"] + draw["winManual"] + draw["winSemi"]


def method_data_start(draws):
    """자동/수동 구분이 처음 등장하는 회차.

    261회차 이하는 winType이 전부 0으로 비어 있다 (2026-08-06 실측, 경계 262).
    1등 당첨자가 실제로 0명인 회차(289·295 등)는 회차 단독으로는 결측과
    구분되지 않으므로, 구분값이 처음 나타난 회차를 경계로 삼고 그 이후를
    통째로 커버 구간으로 본다.
    """
    with_data = [d["round"] for d in draws if method_breakdown_sum(d) > 0]
    return min(with_data) if with_data else None


def method_totals(draws):
    start = method_data_start(draws)
    covered = [d for d in draws if start is not None and d["round"] >= start]
    return {
        "자동": sum(d["winAuto"] for d in covered),
        "수동": sum(d["winManual"] for d in covered),
        "반자동": sum(d["winSemi"] for d in covered),
        "fromRound": min((d["round"] for d in covered), default=None),
        "coveredRounds": len(covered),
    }


def build_stats_payload(draws):
    """stats.json 전체를 만든다.

    앱은 1,200회차를 매번 순회하지 않는다. 여기서 다 계산해 넘긴다.
    JSON 키는 문자열이 되므로 번호 키를 명시적으로 str로 만든다 —
    Flutter 쪽에서 int 키를 기대하다 깨지는 일을 막기 위함이다.
    """
    ordered = sorted(draws, key=lambda d: d["round"])

    def as_str_keys(counts):
        return {str(n): c for n, c in counts.items()}

    return {
        "totalRounds": len(ordered),
        "latestRound": ordered[-1]["round"] if ordered else None,
        "frequency": as_str_keys(number_frequency(ordered)),
        "recentFrequency": {
            str(w): as_str_keys(number_frequency(ordered[-w:]))
            for w in RECENT_WINDOWS
        },
        "drought": as_str_keys(drought(ordered)),
        # 자동/수동은 262회차부터만 존재한다. fromRound를 함께 실어
        # 앱이 "N회차 이후 기준"이라고 고지할 수 있게 한다.
        "method": method_totals(ordered),
    }
