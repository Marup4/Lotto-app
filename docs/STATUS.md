# 진행 상황

> 최종 갱신: 2026-08-07 / 다음 세션이 이 문서부터 읽으면 된다.
> 설계 문서: Notion "앱 개발 설계(초안/임시) 로또" **v0.3**

## 한 줄 요약

Week 0 완료 · Week 1 코드 완료(백필 50%) · **Week 2 진행 중 — ① 당첨번호 탭까지 실기기 구동 확인**

---

## 확정 사항 (되돌리지 말 것)

| 항목 | 값 | 비고 |
|---|---|---|
| 패키지명 | `com.lottolite.app` | Play 등록 후 영구 고정 |
| Flutter 프로젝트명 | `lotto_app` | Dart 패키지명. applicationId와 별개 |
| minSdk | 26 (Android 8) | |
| 번들 데이터 | **당첨번호 최근 100회차** (약 18KB) | 설계 문서 §13-3 (2026-08-07 변경) |
| 저장소 | https://github.com/Marup4/Lotto-app | main 브랜치 |
| 앱 표시 이름 | **미정** | 출시 전까지 변경 가능하므로 급하지 않음 |

## 현재 수치 (2026-08-07)

- 최신 회차 **1235** (2026-08-01)
- 당첨번호 **1235 / 1235 회차** — 누락 없음
- 판매점 **503개 회차 남음** — `.\run.ps1 collect` 약 4회 더 (최신 회차부터 받는다)
- 테스트 **84개** (배치 57 + 앱 27) 전부 통과, `flutter analyze` 무결점

### 앱 번들 회차를 100회로 정한 근거

로또 당첨금 지급 기한은 지급개시일로부터 **1년(약 52회차)** 이다. 그보다
오래된 회차는 내 번호를 대조할 실익이 없다. 100회차면 지급 기한을 두 배
여유로 덮는다. 전 회차(216KB) 대비 18KB로 줄었다.
통계 탭은 `stats.json`(전 회차 사전 계산)을 쓰므로 이 값과 무관하다.
바꾸려면 `batch/build.py`의 `APP_BUNDLE_ROUNDS` 하나만 고치면 된다.

---

## 완료된 것

### Week 0 — 사전 검증 ✅

동행복권 사이트 개편으로 설계 문서 v0.2가 전제한 엔드포인트가 전부 폐기된 것을 발견.
신규 JSON API를 찾아 v0.3으로 반영. 자세한 API 스펙은 Notion 부록 A와
[batch/lotto/client.py](../batch/lotto/client.py) 참조.

### Week 1 — 데이터 파이프라인 ✅ (코드) / ⏳ (백필 50%)

```
batch/lotto/
  client.py    API 호출·세션·재시도 (네트워크를 아는 유일한 모듈)
  parse.py     API 응답 → 앱 스키마
  stats.py     빈도·미출현·자동수동 집계
  ranking.py   매장 랭킹 (ltShpId GROUP BY)
  validate.py  배포 전 검증 (실패 시 exit 1)
  collect.py   수집 대상 판단 + 캐시 재사용
  storage.py   경로·읽기/쓰기·해시
batch/build.py 오케스트레이션 (CLI)
```

부수 산출물: `data/index.html`(육안 점검 화면), `run.ps1`,
`.github/workflows/update-data.yml`

### Week 2 — 앱 코어 ⏳ 진행 중

```
app/lib/
  domain/prize.dart      등수 판정 (테스트 10개, 2등/3등 경계 집중)
  domain/draw.dart       회차 모델 + 볼 색상 구간
  data/draw_repository.dart  번들 에셋 로딩
  ui/draw_tab.dart       ① 당첨번호 탭 (회차 선택기 + 스와이프)
  ui/ball.dart           번호 볼
  ui/format.dart         금액 축약 표기
  main.dart              하단 5탭 (②~⑤는 "준비 중" 자리표시)
```

갤럭시 S21(Android 15, `R3CR505Q4QV`) 실기기 구동 확인 완료.

---

## 다음에 할 일

1. **② 내 번호 탭** — 등수 판정 로직은 이미 완성·검증됨. 1–45 그리드 입력 UI와
   저장(drift), 신규 회차 자동 재판정만 붙이면 된다
   (① 탭의 회차 선택기는 2026-08-07 완료)
2. **③ 번호 추천 탭** — 여기까지가 설계 문서의 "출시 가능한 상태"
3. ④ 통계 / ⑤ 판매점·랭킹 — **백필 완료 후에 착수**
4. 릴리스 서명 설정 (아래 함정 참조)
5. AdMob, 아이콘/스플래시, 개인정보처리방침, 내부 테스트 트랙

---

## 발로 밟아 알아낸 함정들

코드만 봐서는 모르는 것들이다. **다시 밟지 말 것.**

### 데이터

- **262회차가 데이터의 분수령이다.** 자동/수동(`winType`)도, **1등 판매점 정보도**
  262회차(2007-12-08)부터 존재한다. 261회 이하는 둘 다 아예 없다.
  동행복권이 그 시점부터 상세 정보를 공개하기 시작한 것으로 보인다.
  - 전 회차를 합산하면 자동 비율이 왜곡된다. `method_totals()`가 `fromRound`를
    함께 반환하므로 **앱은 "262회차 이후 기준"이라고 고지해야 한다**
  - 판매점 경계는 `lotto/store_era.py`의 `STORE_DATA_FIRST_ROUND`로 관리한다.
    이걸 모르면 검증이 250개 회차를 '판매점 0건'으로 오탐해 **배치가 영구 실패**하고,
    항상 빈 응답이 올 회차에 요청을 날려 IP 차단 예산을 낭비한다 (둘 다 실제로 겪음)
- 262회차 이후로는 `winType 합 == 1등 당첨자 수`가 정확히 성립 — 검증에 사용 중
- **1등 당첨자가 0명인 회차가 존재한다** (289·295 등). 판매점 0건이 정상이다
- **총 판매금액은 `wholEpsdSumNtslAmt`다.** `rlvtEpsdSumNtslAmt`는 1~5등 당첨금
  총합(판매액의 50%)이라 그걸 쓰면 화면에 실제의 절반이 찍힌다. 한 번 당했다
- `srchLtEpsd`가 최신 회차를 넘으면 API가 **빈 배열**을 준다. 앵커를 clamp하지
  않으면 마지막 몇 회차가 조용히 누락된다. 실제로 1231~1235가 빠졌었다
- **응답이 비어 있지 않다고 해서 요청한 회차가 존재하는 건 아니다.** 창(N-5~N+4)이
  겹쳐 앞쪽 회차만 걸릴 수 있다. `latest_round()`는 반드시 요청한 회차 자신이
  목록에 있는지 확인해야 한다 (`_round_exists`)
- **`ltShpId`는 신뢰할 수 있다** (2,291건 검증). 이름+주소가 같은데 ID가 다른
  사례 0건 — 랭킹이 쪼개지지 않는다. 같은 ID에 이름이 여러 개인 경우는 26건이며
  상호 변경이므로 최신 표기를 쓰면 된다
- **매장명·시군구가 `null`인 레코드가 있다** (578회 이름, 572회 시군구).
  `parse_store`가 막고 있으나 새 필드를 쓸 땐 결측을 항상 의심할 것
- **반자동은 판매점 데이터에서 아직 한 건도 관측되지 않았다** (자동 1578 / 수동 713).
  `winType3`은 0이 아닌 회차가 있으므로 백필 완료 후 재확인 필요.
  §7 F6의 배지 3색 중 보라가 안 쓰일 가능성

### 운영

- **요청을 촘촘히 보내면 IP가 차단된다.** 0.5초 간격 600회로 차단당했다
  (다른 사이트는 정상, 동행복권만 ConnectTimeout). `--delay 1.2` 이상 유지하고
  최초 백필은 `--max-stores 150`으로 끊어서 여러 번. 주간 증분은 요청 1~2회라 무관
- 판매점은 회차마다 즉시 저장되므로 중단돼도 이어받는다

### 환경

- **한글이 든 `.ps1`은 UTF-8 with BOM으로 저장해야 한다.** Windows PowerShell
  5.1은 BOM이 없으면 cp949로 읽어 따옴표가 깨지고 파싱 자체가 실패한다.
  Write/Edit 도구는 BOM을 안 붙이므로 수정할 때마다 다시 붙일 것
- PowerShell `>` 리디렉션은 바이너리를 망친다 (스크린샷 등은 Bash에서)
- `flutter install`은 기본으로 release를 찾는다. `--debug` 명시 필요
- Android Studio가 `D:\Dev\AS_Studio`에 있어 `flutter doctor` 요약에 안 뜬다.
  정상 인식 중이니 문제 아님

---

## 아직 막혀 있는 것

### ⚠️ 릴리스 서명이 디버그 키다

`app/android/app/build.gradle.kts`:

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")   // flutter create 기본값
}
```

이 상태로 AAB를 만들면 **Play Console이 거부한다.** 출시 전 키스토어 생성 →
`key.properties` 분리 → Play App Signing 등록이 필요하다.
**키스토어를 잃으면 그 앱은 영원히 업데이트 불가다. 반드시 백업할 것.**

### 사용자가 해야 하는 것 (내가 못 함)

- [ ] 백필 마무리 — `.\run.ps1 collect` 약 5회
- [ ] **매장 랭킹 육안 확인** — 백필 후 `.\run.ps1 view`에서 같은 매장이 두 줄로
      쪼개져 있는지. `ltShpId` 안정성 검증이며 **테스트로는 판정 불가**
- [ ] GitHub Pages 소스를 Actions로 설정
- [ ] Secrets에 `DATA_PAT` 등록 (없으면 60일 뒤 cron 자동 중지)
- [ ] Google Play 도박 정책 확인, AdMob 계정, Play Console 개발자 등록

### 에뮬레이터

미생성. 실기기(API 35)로 개발 중이라 급하지 않으나, **minSdk 26 호환성은
실기기로 검증할 수 없다.** Week 3 출시 전 API 26 AVD 생성 필요
(시스템 이미지 약 1.5GB 다운로드).

---

## 자주 쓰는 명령

```powershell
.\run.ps1 test      # 배치 테스트
.\run.ps1 check     # 동행복권 접속 가능 여부 (차단 확인)
.\run.ps1 collect   # 백필 이어받기
.\run.ps1 status    # 수집 현황
.\run.ps1 view      # 데이터 육안 점검 (localhost:8765)
.\run.ps1 update    # 주간 증분 갱신

cd app
flutter test
flutter build apk --debug
flutter install --debug -d R3CR505Q4QV
```

앱 에셋(`app/assets/data/draws.json`)은 배치가 자동으로 함께 갱신하므로
수동 복사가 필요 없다.
