"""주 1회 배치: 동행복권 API → 정적 JSON (GitHub Pages 배포 대상).

  python build.py                    증분 갱신 (주간 운영, 요청 1~2회)
  python build.py --full             draws.json을 무시하고 전 회차 재수집
  python build.py --max-stores 300   판매점을 300회차만 받고 종료 (나눠 받기)

판매점 캐시(data/stores/)는 모드와 무관하게 항상 재사용된다.
강제로 다시 받으려면 해당 폴더를 지운다.

검증에 실패하면 exit 1로 죽는다. 성공으로 끝나고 빈 파일을
배포하는 게 최악이다 (계획서 §5-①).
"""
import argparse
import sys

from lotto.client import DhLottery, SiteUnreachable
from lotto.collect import collect_draws, collect_stores
from lotto.ranking import build_ranking
from lotto.stats import build_stats_payload
from lotto.storage import DATA, load_json, write_json
from lotto.validate import validate

RECENT_WINDOW = 50      # draws-latest.json에 담을 회차 수
RANKING_LIMIT = 50      # 매장 랭킹 TOP N
DEFAULT_HINT = 1235     # 최신 회차 탐색 시작점 (2026-08-06 기준)


def parse_args():
    ap = argparse.ArgumentParser(description="로또 데이터 배치")
    ap.add_argument("--full", action="store_true",
                    help="draws.json을 무시하고 전 회차를 다시 받는다")
    ap.add_argument("--delay", type=float, default=1.0,
                    help="요청 간 간격(초). 낮추면 IP가 차단될 수 있다")
    ap.add_argument("--max-stores", type=int, default=None,
                    help="이번 실행에서 받을 판매점 회차 수 상한")
    return ap.parse_args()


def load_known_draws(full):
    """--full이면 캐시를 버리고 처음부터 받는다."""
    if full:
        return {}
    return {d["round"]: d for d in load_json(DATA / "draws.json", [])}


def write_outputs(draw_list, all_stores, stores, latest):
    """정적 JSON 일체를 쓰고 manifest를 갱신한다.

    manifest의 해시로 앱이 '무엇이 바뀌었는지' 판단해
    변경된 파일만 내려받는다 (계획서 §4).
    회차별 판매점 파일은 수집 단계에서 이미 저장됐으므로 여기서 다시 쓰지 않는다.
    """
    files = {
        "draws.json": write_json(DATA / "draws.json", draw_list),
        "draws-latest.json": write_json(
            DATA / "draws-latest.json", draw_list[-RECENT_WINDOW:]),
        "stats.json": write_json(
            DATA / "stats.json", build_stats_payload(draw_list)),
        "store-ranking.json": write_json(
            DATA / "store-ranking.json",
            build_ranking(all_stores, limit=RANKING_LIMIT)),
    }
    write_json(DATA / "manifest.json", {
        "latestRound": latest,
        "totalRounds": len(draw_list),
        "storeRounds": sorted(stores),
        "files": files,
    })
    return files


def fail(problems):
    print("\n검증 실패 — 배포하지 않는다:", file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)


def main():
    args = parse_args()

    previous_latest = load_json(DATA / "manifest.json", {}).get("latestRound")

    print("동행복권 API 접속…")
    try:
        api = DhLottery(delay=args.delay)
        latest = api.latest_round(hint=previous_latest or DEFAULT_HINT)
    except SiteUnreachable as e:
        print(f"\n{e}", file=sys.stderr)
        sys.exit(1)
    print(f"  최신 회차: {latest}")

    draws = collect_draws(api, latest, load_known_draws(args.full))
    stores, remaining = collect_stores(api, draws, max_requests=args.max_stores)

    # 아직 못 받은 회차가 있으면 랭킹·검증이 성립하지 않는다.
    # 캐시만 쌓아두고 정상 종료한다 — 다음 실행이 이어받는다.
    if remaining:
        print(f"\n판매점 {remaining}개 회차가 남았다. "
              f"전량 수집 후에 파생 파일을 만든다.")
        print("잠시 뒤 다시 실행할 것 (--max-stores 로 나눠 받는 중).")
        return

    draw_list = sorted(draws.values(), key=lambda d: d["round"])
    all_stores = [s for r in sorted(stores) for s in stores[r]]

    problems = validate(draw_list, all_stores, previous_latest)
    if problems:
        fail(problems)

    write_outputs(draw_list, all_stores, stores, latest)
    print(f"\n완료: {len(draw_list)}회차 / 판매점 {len(all_stores)}건 → {DATA}")


if __name__ == "__main__":
    main()
