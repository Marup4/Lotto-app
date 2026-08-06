"""API에서 원본을 받아 앱 스키마로 쌓는 단계.

여기서는 '무엇을 받아야 하는지' 판단과 캐시 재사용만 다룬다.
가공(통계·랭킹)은 stats/ranking, 저장은 storage가 맡는다.
"""
from lotto.client import plan_rounds
from lotto.parse import parse_draw, parse_store
from lotto.storage import load_json, store_path, write_json


def collect_draws(api, latest, known):
    """1회차부터 latest까지 당첨번호를 채운다.

    known(이미 가진 회차)에 없는 구간만 요청한다. 주간 갱신에서는
    보통 마지막 앵커 1회만 호출된다.
    """
    draws = dict(known)
    missing = [r for r in range(1, latest + 1) if r not in draws]
    if not missing:
        print("  당첨번호: 최신 상태")
        return draws

    # 결측 회차를 포함하는 앵커만 고른다 (앵커 N은 N-5~N+4를 덮는다)
    anchors = sorted({
        a for a in plan_rounds(latest)
        if any(a - 5 <= m < a + 5 for m in missing)
    })
    print(f"  당첨번호 {len(missing)}개 회차 부족 → {len(anchors)}회 요청")
    for i, anchor in enumerate(anchors, 1):
        for raw in api.draws_around(anchor):
            d = parse_draw(raw)
            draws[d["round"]] = d
        if i % 20 == 0:
            print(f"    {i}/{len(anchors)}", flush=True)
    return draws


def collect_stores(api, draws, max_requests=None):
    """1등 판매점을 회차별로 받아 즉시 파일로 떨어뜨린다.

    받는 즉시 저장하므로 중간에 죽거나 차단당해도 다음 실행이 이어받는다.
    max_requests를 주면 그만큼만 받고 멈춘다 — 전 회차 최초 수집을
    여러 번에 나눠 받아 IP 차단을 피하기 위한 장치다.

    반환: {회차: [판매점, …]} 와 남은 회차 수
    """
    stores = {}
    todo = []

    for d in sorted(draws.values(), key=lambda x: x["round"]):
        r = d["round"]
        cached = store_path(r)
        if cached.exists():
            stores[r] = load_json(cached, [])
        elif d["firstWinners"] == 0:
            # 289·295회처럼 1등이 0명인 회차가 실제로 있다. 요청할 필요가 없다.
            stores[r] = []
            write_json(cached, [])
        else:
            todo.append(r)

    if not todo:
        print("  판매점: 최신 상태")
        return stores, 0

    batch = todo if max_requests is None else todo[:max_requests]
    remaining = len(todo) - len(batch)
    print(f"  판매점 {len(todo)}개 회차 부족 → 이번에 {len(batch)}개 요청"
          + (f" (남은 {remaining}개는 다음 실행에서)" if remaining else ""))

    for i, r in enumerate(batch, 1):
        stores[r] = [parse_store(raw, r) for raw in api.first_prize_stores(r)]
        write_json(store_path(r), stores[r])
        if i % 50 == 0:
            print(f"    {i}/{len(batch)}", flush=True)

    return stores, remaining
