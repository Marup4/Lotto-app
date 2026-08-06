"""배치 산출물 검증 (계획서 §5-① 무인 운영 안전장치).

성공으로 끝나고 빈 파일을 배포하는 게 최악이다.
문제가 하나라도 있으면 build.py가 exit 1로 죽는다.
"""


from lotto.stats import method_breakdown_sum, method_data_start


def validate(draws, stores, previous_latest, stores_complete=True, latest=None):
    """산출물이 배포해도 되는 상태인지 확인한다.

    stores_complete=False 는 백필을 나눠 받는 중이라는 뜻으로,
    아직 안 받은 회차를 '판매점 0건'으로 오탐하지 않는다.

    latest를 주면 수집이 최신 회차까지 닿았는지도 본다. 중간 누락만
    검사하면 꼬리가 통째로 잘린 경우를 놓친다.
    """
    problems = []
    if not draws:
        return ["당첨번호가 0건이다 — 수집 실패로 간주한다"]

    rounds = sorted(d["round"] for d in draws)
    missing = set(range(rounds[0], rounds[-1] + 1)) - set(rounds)
    if missing:
        shown = ", ".join(str(r) for r in sorted(missing)[:10])
        problems.append(f"회차 누락: {shown}")

    collected_latest = rounds[-1]
    if previous_latest is not None and collected_latest < previous_latest:
        problems.append(
            f"최신 회차가 후퇴했다: {previous_latest} → {collected_latest}")

    if latest is not None and collected_latest < latest:
        problems.append(
            f"최신 회차 {latest}까지 못 받았다 — {collected_latest}회차에서 끊겼다")

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
        if (stores_complete and d["firstWinners"] > 0
                and stores_by_round.get(d["round"], 0) == 0):
            problems.append(
                f"{d['round']}회차는 1등 당첨자가 {d['firstWinners']}명인데 판매점이 0건이다"
            )

    return problems
