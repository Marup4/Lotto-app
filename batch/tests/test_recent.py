from lotto.recent import build_recent_stores


def shop(name):
    return {"shopId": "A", "name": name, "address": "서울 강남구 어디로 1",
            "sido": "서울", "sigungu": "강남구", "method": "자동"}


def test_keeps_only_the_most_recent_rounds():
    by_round = {r: [shop(f"{r}호")] for r in range(1200, 1236)}

    recent = build_recent_stores(by_round, limit=3)

    assert sorted(recent) == ["1233", "1234", "1235"]


def test_keeps_an_empty_round_as_empty():
    # 289·295회처럼 1등이 진짜 0명인 회차. '자료 없음'과 구별해 보여줘야 한다
    recent = build_recent_stores({1234: [shop("가")], 1235: []}, limit=2)

    assert recent["1235"] == []


def test_returns_everything_when_fewer_rounds_exist():
    assert len(build_recent_stores({1235: [shop("가")]}, limit=10)) == 1


def test_keys_are_strings_for_json():
    # JSON 객체 키는 문자열이다. int로 두면 직렬화 후 앱에서 키가 어긋난다
    recent = build_recent_stores({1235: []})

    assert list(recent) == ["1235"]
