# 로또 앱 개발용 실행 스크립트
#
#   .\run.ps1 test        유닛 테스트
#   .\run.ps1 collect     판매점 150회차씩 수집 (여러 번 반복 실행)
#   .\run.ps1 update      주간 증분 갱신 (신규 회차만)
#   .\run.ps1 view        브라우저로 데이터 점검 화면 열기
#   .\run.ps1 status      현재 수집 상태만 확인
#   .\run.ps1 check       동행복권 접속 가능 여부 확인

param([Parameter(Position = 0)][string]$Cmd = "status")

$Root = $PSScriptRoot
$Py = Join-Path $Root ".venv\Scripts\python.exe"
$Batch = Join-Path $Root "batch"
$Data = Join-Path $Root "data"

if (-not (Test-Path $Py)) {
    Write-Host "가상환경이 없다. 먼저 아래를 실행할 것:" -ForegroundColor Yellow
    Write-Host "  py -m venv .venv"
    Write-Host "  .venv\Scripts\python.exe -m pip install -r batch\requirements.txt"
    exit 1
}

switch ($Cmd) {
    "test" {
        Push-Location $Batch
        & $Py -m pytest -q
        Pop-Location
    }

    "check" {
        # 요청을 너무 촘촘히 보내면 IP가 차단된다. 그때 여기서 확인한다.
        & $Py -c @"
import requests
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'}
try:
    r=requests.get('https://www.dhlottery.co.kr/lt645/result',headers=H,timeout=15)
    print('OK: HTTP', r.status_code, '-', len(r.content), 'bytes')
except Exception as e:
    print('BLOCKED:', type(e).__name__, '- wait and retry')
"@
    }

    "collect" {
        # 최초 백필. 한 번에 다 받으면 차단되므로 끊어서 여러 번 돌린다.
        Push-Location $Batch
        & $Py -u build.py --max-stores 150 --delay 1.2
        Pop-Location
    }

    "update" {
        # 주간 운영 경로. 요청이 1~2회뿐이라 차단과 무관하다.
        Push-Location $Batch
        & $Py -u build.py --delay 1.2
        Pop-Location
    }

    "view" {
        if (-not (Test-Path (Join-Path $Data "draws.json"))) {
            Write-Host "아직 데이터가 없다. 먼저 .\run.ps1 collect 를 실행할 것." -ForegroundColor Yellow
            exit 1
        }
        Write-Host "http://localhost:8765 에서 확인. 종료는 Ctrl+C." -ForegroundColor Cyan
        Start-Process "http://localhost:8765"
        Push-Location $Data
        & $Py -m http.server 8765
        Pop-Location
    }

    "status" {
        $manifest = Join-Path $Data "manifest.json"
        $storeDir = Join-Path $Data "stores"
        $storeCount = 0
        if (Test-Path $storeDir) {
            $storeCount = (Get-ChildItem $storeDir -Filter *.json).Count
        }
        if (Test-Path $manifest) {
            $m = Get-Content $manifest -Raw | ConvertFrom-Json
            Write-Host "최신 회차       : $($m.latestRound)"
            Write-Host "당첨번호 회차   : $($m.totalRounds)"
        } else {
            Write-Host "manifest 없음 - 전량 수집이 아직 안 끝났다"
        }
        Write-Host "판매점 보유 회차: $storeCount"
        if (Test-Path $manifest) {
            Write-Host "`n완료. .\run.ps1 view 로 확인할 것." -ForegroundColor Green
        } else {
            Write-Host "`n.\run.ps1 collect 를 반복 실행할 것 (사이에 10분 이상 간격)." -ForegroundColor Yellow
        }
    }

    default {
        Write-Host "사용법: .\run.ps1 [test|check|collect|update|view|status]"
    }
}
