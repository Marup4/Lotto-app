"""주 1회 배치: 동행복권 API → 정적 JSON (GitHub Pages 배포 대상).

기본은 증분 모드 — 이미 받아둔 회차는 다시 요청하지 않는다.
--full 을 주면 전 회차를 새로 수집한다 (최초 1회).

검증에 실패하면 exit 1. 빈 파일을 성공으로 배포하는 게 최악이다 (계획서 §5-①).
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

from lotto.client import DhLottery, plan_rounds
from lotto.parse import parse_draw, parse_store
from lotto.ranking import build_ranking
from lotto.stats import drought, method_totals, number_frequency
from lotto.validate import validate

DATA = Path(__file__).resolve().parent.parent / "data"
RECENT_WINDOW = 50
RANKING_LIMIT = 50


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    path.write_text(text, encoding="utf-8")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def load_json(path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def collect_draws(api, latest, known):
    """known에 없는 회차만 채운다."""
    draws = dict(known)
    missing = [r for r in range(1, latest + 1) if r not in draws]
    if not missing:
        return draws

    needed_anchors = sorted({
        a for a in plan_rounds(latest)
        if any(a - 5 <= m < a + 5 for m in missing)
    })
    print(f"  당첨번호 {len(missing)}개 회차 부족 → {len(needed_anchors)}회 요청")
    for i, anchor in enumerate(needed_anchors, 1):
        for raw in api.draws_around(anchor):
            d = parse_draw(raw)
            draws[d["round"]] = d
        if i % 20 == 0:
            print(f"    {i}/{len(needed_anchors)}")
    return draws


def collect_stores(api, draws, known_rounds):
    """1등 당첨자가 있는 회차 중 아직 안 받은 것만 요청한다."""
    stores = {}
    todo = []
    for d in sorted(draws.values(), key=lambda x: x["round"]):
        r = d["round"]
        cached = DATA / "stores" / f"{r}.json"
        if r in known_rounds and cached.exists():
            stores[r] = json.loads(cached.read_text(encoding="utf-8"))
        elif d["firstWinners"] == 0:
            stores[r] = []          # 1등 없는 회차는 요청할 필요 없다
        else:
            todo.append(r)

    if todo:
        print(f"  판매점 {len(todo)}개 회차 요청")
    for i, r in enumerate(todo, 1):
        stores[r] = [parse_store(raw, r) for raw in api.first_prize_stores(r)]
        if i % 20 == 0:
            print(f"    {i}/{len(todo)}")
    return stores


def build_stats(draw_list):
    recent = sorted(draw_list, key=lambda d: d["round"])[-RECENT_WINDOW:]
    return {
        "frequency": number_frequency(draw_list),
        "recentFrequency": {
            str(w): number_frequency(sorted(draw_list, key=lambda d: d["round"])[-w:])
            for w in (10, 30, 50)
        },
        "drought": drought(draw_list),
        "method": method_totals(draw_list),
        "recentRounds": [d["round"] for d in recent],
        "totalRounds": len(draw_list),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--full", action="store_true", help="전 회차 재수집")
    ap.add_argument("--delay", type=float, default=1.0, help="요청 간 딜레이(초)")
    args = ap.parse_args()

    previous = load_json(DATA / "manifest.json", {})
    previous_latest = previous.get("latestRound")

    print("동행복권 API 접속…")
    api = DhLottery(delay=args.delay)
    latest = api.latest_round(hint=previous_latest or 1235)
    print(f"  최신 회차: {latest}")

    known_draws = {}
    known_store_rounds = set()
    if not args.full:
        for d in load_json(DATA / "draws.json", []):
            known_draws[d["round"]] = d
        known_store_rounds = {int(p.stem) for p in (DATA / "stores").glob("*.json")}

    draws = collect_draws(api, latest, known_draws)
    stores = collect_stores(api, draws, known_store_rounds)

    draw_list = sorted(draws.values(), key=lambda d: d["round"])
    all_stores = [s for r in sorted(stores) for s in stores[r]]

    problems = validate(draw_list, all_stores, previous_latest)
    if problems:
        print("\n검증 실패:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        sys.exit(1)

    files = {}
    files["draws.json"] = write_json(DATA / "draws.json", draw_list)
    files["draws-latest.json"] = write_json(
        DATA / "draws-latest.json", draw_list[-RECENT_WINDOW:])
    files["stats.json"] = write_json(DATA / "stats.json", build_stats(draw_list))
    files["store-ranking.json"] = write_json(
        DATA / "store-ranking.json", build_ranking(all_stores, limit=RANKING_LIMIT))
    for r, items in stores.items():
        write_json(DATA / "stores" / f"{r}.json", items)

    write_json(DATA / "manifest.json", {
        "latestRound": latest,
        "totalRounds": len(draw_list),
        "storeRounds": sorted(stores),
        "files": files,
    })

    print(f"\n완료: {len(draw_list)}회차, 판매점 {len(all_stores)}건 → {DATA}")


if __name__ == "__main__":
    main()
