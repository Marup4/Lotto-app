"""API에서 원본을 받아 앱 스키마로 쌓는 단계.

여기서는 '무엇을 받아야 하는지' 판단과 캐시 재사용만 다룬다.
가공(통계·랭킹)은 stats/ranking, 저장은 storage가 맡는다.
"""
from lotto.client import plan_rounds
from lotto.parse import parse_draw, parse_store
from lotto.storage import load_json, store_path, write_json
from lotto.store_era import has_store_data


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


def is_settled_without_winner(draw):
    """집계가 끝났는데 1등이 진짜 0명인 회차인가 (289·295 등).

    `firstWinners == 0` 만으로 판단하면 안 된다. 추첨 직후에는 당첨번호만
    나오고 집계는 나중에 채워지므로, 갓 추첨된 회차도 0명으로 보인다.
    그걸 '1등 없음'으로 확정해 빈 파일을 캐시에 남기면, 당첨금이 확정된
    뒤에도 다음 실행이 '이미 받았다'며 건너뛴다 — 신규 회차의 판매점이
    영영 비게 되고 랭킹도 그때부터 멈춘다.

    총 판매금액으로 둘을 가른다. 1등이 0명인 회차도 판매금액은 정상값이다.
    앱의 `Draw.isSettled`와 같은 기준이다.
    """
    return draw["firstWinners"] == 0 and draw["totalSales"] > 0


def rounds_needing_stores(draws, cached):
    """실제로 요청해야 하는 회차를 최신순으로 돌려준다.

    요청할 필요가 없는 경우가 셋 있다.
      - 이미 받아둔 회차 (cached)
      - 261회차 이하 — 동행복권이 공개하지 않는다. 요청해도 항상 빈 응답이라
        IP 차단 예산만 낭비한다
      - 1등 당첨자가 0명인 회차 (289·295 등)

    최신순인 이유: 백필을 도중에 멈춰도 사용자가 실제로 보는 최근 회차부터
    쓸 수 있어야 한다. 설계 문서 §13-3의 '판매점 최근 100회차 번들링'과도 맞다.
    """
    return sorted(
        (d["round"] for d in draws.values()
         if d["round"] not in cached
         and has_store_data(d["round"])
         and d["firstWinners"] > 0),
        reverse=True,
    )


def collect_stores(api, draws, max_requests=None):
    """1등 판매점을 회차별로 받아 즉시 파일로 떨어뜨린다.

    받는 즉시 저장하므로 중간에 죽거나 차단당해도 다음 실행이 이어받는다.
    max_requests를 주면 그만큼만 받고 멈춘다 — 전 회차 최초 수집을
    여러 번에 나눠 받아 IP 차단을 피하기 위한 장치다.

    반환: {회차: [판매점, …]} 와 남은 회차 수
    """
    stores = {}
    cached_rounds = set()

    for d in sorted(draws.values(), key=lambda x: x["round"]):
        r = d["round"]
        path = store_path(r)
        if path.exists():
            stores[r] = load_json(path, [])
            cached_rounds.add(r)
        elif not has_store_data(r) or is_settled_without_winner(d):
            # 요청할 이유가 없는 회차. 빈 값으로 확정해 캐시에 남긴다.
            stores[r] = []
            write_json(path, [])
        # 집계 전 회차는 아무것도 하지 않는다. 빈 파일을 남기면 다음 실행이
        # '이미 받았다'고 보고 영영 건너뛴다 (아래 함수 주석 참조).

    todo = rounds_needing_stores(draws, cached_rounds)
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
