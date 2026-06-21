@echo off
setlocal
set "GODOT=C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
set "PYTHON=C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
set "PROJECT_DIR=%~dp0."
set "OUT_DIR=%~dp0..\AshenOath_Web_Slim"

if not exist "%GODOT%" (
  echo Godot 4.6.3 console executable was not found at:
  echo %GODOT%
  exit /b 1
)
if not exist "%PYTHON%" (
  echo Python runtime was not found at:
  echo %PYTHON%
  exit /b 1
)

if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

"%GODOT%" --headless --path "%PROJECT_DIR%" --export-release "Web Browser Slim" "%OUT_DIR%\index.html"
if errorlevel 1 exit /b %errorlevel%

"%PYTHON%" "%PROJECT_DIR%\tools\verify_web_export.py" "%OUT_DIR%"
if errorlevel 1 exit /b %errorlevel%

echo.
echo Web build ready:
echo %OUT_DIR%
echo Upload the contents of this folder to Vercel, Netlify, Cloudflare Pages, or itch.io.
