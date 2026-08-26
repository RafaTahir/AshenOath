@echo off
setlocal
if defined GODOT_BIN (
  set "GODOT=%GODOT_BIN%"
) else (
  set "GODOT=%USERPROFILE%\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe"
)
if not exist "%GODOT%" set "GODOT=C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
set "PYTHON=C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
set "PROJECT_DIR=%~dp0."
set "OUT_DIR=%~dp0..\AshenOath_Web"

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

set "PACK_DIR=%ASHEN_OATH_PACK_DIRECTORY%"
if not defined PACK_DIR set "PACK_DIR=%PROJECT_DIR%\.release-gate\runtime-packs"
set "MISSING_PACK="
for %%P in (opening campaign characters monsters audio) do (
  if not exist "%PACK_DIR%\%%P.pck" set "MISSING_PACK=1"
)
rem Rebuild packs by default so an export cannot silently reuse stale source content.
rem Set ASHEN_OATH_REUSE_PACKS=1 only for an intentional local iteration.
if not defined ASHEN_OATH_REUSE_PACKS set "MISSING_PACK=1"
if defined MISSING_PACK (
  echo Building the verified runtime packs...
  powershell -ExecutionPolicy Bypass -File "%PROJECT_DIR%\tools\build_runtime_packs.ps1" -OutputDirectory "%PACK_DIR%" -Force
  if errorlevel 1 exit /b %errorlevel%
)

if not exist "%PACK_DIR%\runtime_pack_candidates.json" (
  echo Runtime pack candidate manifest was not produced:
  echo %PACK_DIR%\runtime_pack_candidates.json
  exit /b 1
)

"%PYTHON%" "%PROJECT_DIR%\tools\sync_runtime_pack_manifest.py" "%PROJECT_DIR%\runtime_pack_manifest.json" "%PACK_DIR%\runtime_pack_candidates.json"
if errorlevel 1 exit /b %errorlevel%

if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

rem Export the embedded PCK only after external pack hashes are synchronized.
"%GODOT%" --headless --path "%PROJECT_DIR%" --export-release "Web Browser" "%OUT_DIR%\index.html"
if errorlevel 1 exit /b %errorlevel%

if not exist "%OUT_DIR%\packs" mkdir "%OUT_DIR%\packs"
for %%P in (opening campaign characters monsters audio) do (
  copy /Y "%PACK_DIR%\%%P.pck" "%OUT_DIR%\packs\%%P.pck" >nul
  if errorlevel 1 exit /b %errorlevel%
)

"%PYTHON%" "%PROJECT_DIR%\tools\verify_web_export.py" "%OUT_DIR%"
if errorlevel 1 exit /b %errorlevel%

echo.
echo Web build ready:
echo %OUT_DIR%

echo Upload the contents of this folder to Vercel, Netlify, Cloudflare Pages, or itch.io.
