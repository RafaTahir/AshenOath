@echo off
setlocal
set "PYTHON=C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
set WEB_DIR=%~dp0..\AshenOath_Web

if not exist "%WEB_DIR%\index.html" (
  echo Web build was not found. Run Export_Web_Build.bat first.
  exit /b 1
)

echo Serving:
echo %WEB_DIR%
echo.
echo Open http://127.0.0.1:8080 in Chrome, Edge, or Firefox.
cd /d "%WEB_DIR%"
"%PYTHON%" -m http.server 8080 --bind 127.0.0.1
