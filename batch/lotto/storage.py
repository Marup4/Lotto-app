"""정적 JSON 산출물의 경로와 읽기/쓰기.

data/ 아래 파일들이 곧 GitHub Pages로 배포되는 API다.
앱은 manifest.json의 해시를 비교해 바뀐 파일만 내려받는다 (계획서 §4).
"""
import hashlib
import json
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent.parent / "data"


def store_path(round_no):
    """회차별 1등 판매점 파일 경로."""
    return DATA / "stores" / f"{round_no}.json"


def write_json(path, payload):
    """JSON을 쓰고 내용 해시를 돌려준다.

    해시는 manifest에 실려 앱의 증분 동기화 판단에 쓰인다.
    공백 없이 직렬화하므로 같은 내용이면 항상 같은 해시가 나온다.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    path.write_text(text, encoding="utf-8")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def load_json(path, default):
    """없거나 깨진 파일은 default로 취급한다.

    캐시가 깨졌다고 배치가 죽으면 안 된다. 다시 받으면 그만이다.
    """
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print(f"  경고: {path.name}이(가) 깨져 있어 무시한다")
        return default
