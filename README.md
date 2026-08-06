# 로또 당첨번호 확인 앱

주 1회 갱신되는 로또 데이터를 **서버 운영 없이** 소비하는 경량 Android 앱.

- 설계 문서: Notion "앱 개발 설계(초안/임시) 로또" v0.3
- 패키지명: `com.lottolite.app` (변경 불가)
- 스택: Flutter (앱) + Python (배치) + GitHub Actions/Pages (인프라)

## 구조

```
batch/          주 1회 데이터 수집 배치 (Python)
  lotto/        순수 로직 — 파싱/통계/랭킹/검증
  build.py      오케스트레이션: API → data/*.json
  tests/        유닛 테스트
data/           정적 JSON (GitHub Pages 배포 대상, 배치가 생성)
app/            Flutter 앱 (Week 2 착수 예정)
```

## 데이터 소스에 대한 경고

동행복권 사이트는 개편됐다. 인터넷에 널리 퍼진 예제가 쓰는
`common.do?method=getLottoNumber` 와 `store.do?method=topStore` 는
**둘 다 죽었다** (302 리다이렉트). 2026-08-06 실측 확인.

현재 쓰는 엔드포인트는 [batch/lotto/client.py](batch/lotto/client.py) 참조.
API가 또 바뀌면 `/lt645/result` 와 `/wnprchsplcsrch/home` 의 HTML에서
`ajaxUtil.sendHttpJson(param, "….do", …)` 호출부를 grep하면 현재 스펙을 찾을 수 있다.

## 배치 실행

```bash
cd batch
python -m venv ../.venv && ../.venv/Scripts/pip install -r requirements.txt

python -m pytest -q          # 유닛 테스트
python build.py --full       # 전 회차 최초 수집 (약 10분)
python build.py              # 증분 갱신 (신규 회차만)
```

검증에 실패하면 `exit 1`로 죽는다. 빈 파일을 성공으로 배포하지 않기 위함이다.

## 알려진 데이터 특성

- **최신 회차 1235회** (2026-08-01 기준)
- **자동/수동 구분은 262회차부터** 존재한다. 261회 이하는 `winType`이 전부 0이다.
  전 회차를 그냥 합산하면 자동 비율이 인위적으로 낮아진다 —
  `method_totals()`가 커버 구간을 `fromRound`로 함께 반환하므로 앱은 이를 고지해야 한다.
- 262회차 이후로는 `winType 합 == 1등 당첨자 수`가 정확히 성립한다.
  배치 검증이 이 불변식을 쓴다.
- **1등 당첨자가 0명인 회차가 존재한다** (289·295 등). 판매점 0건이 정상이다.
- 판매점 응답의 `ltShpId`가 매장 고유 ID다. 매장명·주소 문자열 정규화는 필요 없다.

## GitHub 설정 (미완료)

- [ ] 저장소 생성 및 push
- [ ] Settings → Pages: GitHub Actions 소스로 설정
- [ ] Secrets에 `DATA_PAT` 등록 — 없으면 60일 뒤 cron이 자동 중지될 수 있다
- [ ] Actions 실패 알림 켜기
