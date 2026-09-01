#!/bin/bash
cd "$(dirname "$0")"

PORT=8765

PY=""
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
fi

if [ -z "$PY" ]; then
  echo ""
  echo "  Python을 찾을 수 없습니다."
  echo ""
  echo "  https://www.python.org/downloads/ 에서 설치한 뒤 다시 실행해주세요."
  echo "  (macOS는 보통 python3가 기본 설치되어 있습니다. Homebrew: brew install python)"
  echo ""
  read -p "종료하려면 Enter를 누르세요..." _
  exit 1
fi

echo ""
echo "  Prompt Log 를 시작합니다..."
echo "  브라우저가 자동으로 열립니다."
echo ""
echo "  [!] 이 창을 닫으면 종료됩니다. 다 쓰신 뒤 닫아주세요."
echo ""

open "http://localhost:$PORT/prompt-log.html"
"$PY" -m http.server "$PORT"

echo ""
echo "  서버가 종료되었습니다."
echo "  포트 $PORT 가 이미 사용 중이면, 이미 실행 중인 창이 있는지 확인해보세요."
echo ""
read -p "종료하려면 Enter를 누르세요..." _
