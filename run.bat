@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Prompt Log

set PORT=8765

rem Prefer the py launcher; fall back to python on PATH.
set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" (where python >nul 2>&1 && set PY=python)

if "%PY%"=="" (
  echo.
  echo   Python을 찾을 수 없습니다.
  echo.
  echo   https://www.python.org/downloads/ 에서 설치한 뒤 다시 실행해주세요.
  echo   설치할 때 "Add Python to PATH" 를 꼭 체크하세요.
  echo.
  pause
  exit /b 1
)

echo.
echo   Prompt Log 를 시작합니다...
echo   브라우저가 자동으로 열립니다.
echo.
echo   [!] 이 창을 닫으면 종료됩니다. 다 쓰신 뒤 닫아주세요.
echo.

start "" "http://localhost:%PORT%/prompt-log.html"
%PY% -m http.server %PORT%

rem Only reached if the server exits on its own (usually: port already in use).
echo.
echo   서버가 종료되었습니다.
echo   포트 %PORT% 가 이미 사용 중이면, 이미 실행 중인 창이 있는지 확인해보세요.
echo.
pause
