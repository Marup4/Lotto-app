"""최근 회차의 1등 판매점 (⑤ 판매점 탭).

역대 랭킹은 한 번 보면 끝이지만 "이번 회차 1등은 어디서 나왔나"는 매주 바뀐다.
전국을 빠짐없이 다루므로 지역 편중 문제도 생기지 않는다 —
상위 50개만 담으면 강원·대전·제주·세종이 통째로 빠진다 (2026-08-07 실측).
"""

# 앱에 번들되는 회차 수. 10회차면 약 15KB다.
RECENT_ROUNDS = 10


def build_recent_stores(stores_by_round, limit=RECENT_ROUNDS):
    """최근 [limit]개 회차의 판매점을 회차별로 담는다.

    빈 목록도 그대로 담는다 — 1등이 0명인 회차(289·295)를 '자료 없음'과
    구별해 보여줘야 하기 때문이다. 아직 집계되지 않은 회차는 애초에
    이 dict에 키가 없다 (`collect_stores` 참조).

    JSON 키는 문자열이어야 하므로 회차 번호를 문자열로 바꾼다.
    """
    rounds = sorted(stores_by_round)[-limit:]
    return {str(r): stores_by_round[r] for r in rounds}
