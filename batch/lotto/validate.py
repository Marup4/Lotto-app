"""배치 산출물 검증 (계획서 §5-① 무인 운영 안전장치).

성공으로 끝나고 빈 파일을 배포하는 게 최악이다.
문제가 하나라도 있으면 build.py가 exit 1로 죽는다.
"""


from lotto.stats import method_breakdown_sum, method_data_start


def validate(draws, stores, previous_latest):
    problems = []
    if not draws:
        return ["당첨번호가 0건이다 — 수집 실패로 간주한다"]

    rounds = sorted(d["round"] for d in draws)
    missing = set(range(rounds[0], rounds[-1] + 1)) - set(rounds)
    if missing:
        shown = ", ".join(str(r) for r in sorted(missing)[:10])
        problems.append(f"회차 누락: {shown}")

    latest = rounds[-1]
    if previous_latest is not None and latest < previous_latest:
        problems.append(f"최신 회차가 후퇴했다: {previous_latest} → {latest}")

    start = method_data_start(draws)
    stores_by_round = {}
    for s in stores:
        stores_by_round[s["round"]] = stores_by_round.get(s["round"], 0) + 1

    for d in draws:
        if start is not None and d["round"] >= start:
            if method_breakdown_sum(d) != d["firstWinners"]:
                problems.append(
                    f"{d['round']}회차 자동/수동 합({method_breakdown_sum(d)})이 "
                    f"1등 당첨자 수({d['firstWinners']})와 다르다"
                )
        if d["firstWinners"] > 0 and stores_by_round.get(d["round"], 0) == 0:
            problems.append(
                f"{d['round']}회차는 1등 당첨자가 {d['firstWinners']}명인데 판매점이 0건이다"
            )

    return problems
