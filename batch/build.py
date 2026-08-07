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
from lotto.ranking import build_ranking_payload
from lotto.recent import build_recent_stores
from lotto.stats import build_stats_payload
from lotto.storage import (APP_ASSET_DRAWS, APP_ASSET_RANKING,
                           APP_ASSET_RECENT_STORES, DATA,
                           load_json, write_json)
from lotto.validate import validate

RANKING_LIMIT = 50      # 매장 랭킹 TOP N
DEFAULT_HINT = 1235     # 최신 회차 탐색 시작점 (2026-08-06 기준)

# 앱이 쓰는 회차 수 (설계 문서 §13-3).
# 로또 당첨금 지급 기한은 지급개시일로부터 1년(약 52회차)이다. 그보다 오래된
# 회차는 내 번호를 대조할 실익이 없다. 지급 기한을 두 배 여유로 덮는 선.
# 통계 탭은 stats.json(전 회차 사전 계산)을 쓰므로 이 값과 무관하다.
#
# 앱 번들과 동기화용 draws-latest.json이 **같은 내용**이어야 한다.
# 둘이 어긋나면 갱신 후 회차 수가 들쭉날쭉해진다. 그래서 상수 하나로 묶는다.
APP_BUNDLE_ROUNDS = 100


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


def write_outputs(draw_list, all_stores, stores, latest, complete):
    """정적 JSON 일체를 쓰고 manifest를 갱신한다.

    manifest의 해시로 앱이 '무엇이 바뀌었는지' 판단해
    변경된 파일만 내려받는다 (계획서 §4).
    회차별 판매점 파일은 수집 단계에서 이미 저장됐으므로 여기서 다시 쓰지 않는다.

    complete=False(백필 진행 중)면 당첨번호까지만 쓴다. 통계와 랭킹은
    판매점이 전량 모여야 의미가 있으므로 만들지 않는다.
    """
    # 앱이 내려받는 파일. 회차가 늘면 창이 통째로 밀린다
    # (1136~1235 → 1137~1236). 18KB뿐이라 증분 계산보다 통째 교체가 싸다.
    recent = draw_list[-APP_BUNDLE_ROUNDS:]

    files = {
        "draws.json": write_json(DATA / "draws.json", draw_list),
        "draws-latest.json": write_json(DATA / "draws-latest.json", recent),
    }
    # 앱 번들 사본도 같은 내용으로 갱신한다. 수동 복사에 의존하면
    # 잊고 빌드했을 때 낡은 데이터가 조용히 출시된다.
    if APP_ASSET_DRAWS.parent.exists():
        write_json(APP_ASSET_DRAWS, recent)
    if complete:
        files["stats.json"] = write_json(
            DATA / "stats.json", build_stats_payload(draw_list))
        ranking = build_ranking_payload(all_stores, limit=RANKING_LIMIT)
        files["store-ranking.json"] = write_json(
            DATA / "store-ranking.json", ranking)

        # 최근 회차 1등 판매점. 매주 바뀌는 유일한 판매점 정보다.
        recent_stores = build_recent_stores(stores)
        files["recent-stores.json"] = write_json(
            DATA / "recent-stores.json", recent_stores)

        # 둘 다 앱에 번들한다. 합쳐 30KB뿐이고, 네트워크가 없어도
        # ⑤ 탭이 빈 화면으로 보이지 않아야 한다.
        if APP_ASSET_RANKING.parent.exists():
            write_json(APP_ASSET_RANKING, ranking)
            write_json(APP_ASSET_RECENT_STORES, recent_stores)

    write_json(DATA / "manifest.json", {
        "latestRound": latest,
        "totalRounds": len(draw_list),
        "storeRounds": sorted(stores),
        # 앱은 complete=false 인 데이터를 신뢰해선 안 된다 (백필 진행 중)
        "complete": complete,
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

    draw_list = sorted(draws.values(), key=lambda d: d["round"])
    all_stores = [s for r in sorted(stores) for s in stores[r]]
    complete = remaining == 0

    problems = validate(draw_list, all_stores, previous_latest,
                        stores_complete=complete, latest=latest)
    if problems:
        fail(problems)

    # 백필 진행 중이라도 당첨번호는 저장한다 — 진행 상황을 눈으로 볼 수 있게.
    write_outputs(draw_list, all_stores, stores, latest, complete)

    if complete:
        print(f"\n완료: {len(draw_list)}회차 / 판매점 {len(all_stores)}건 → {DATA}")
    else:
        print(f"\n당첨번호 {len(draw_list)}회차 저장 완료.")
        print(f"판매점 {remaining}개 회차가 남았다 (통계·랭킹은 전량 수집 후 생성).")
        print("잠시 뒤 다시 실행할 것.")


if __name__ == "__main__":
    main()
