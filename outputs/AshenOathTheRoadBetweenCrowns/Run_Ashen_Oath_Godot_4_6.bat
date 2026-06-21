@echo off
setlocal
set "PROJECT_DIR=%~dp0"
set "GODOT=%USERPROFILE%\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe"

if not exist "%GODOT%" (
  set "GODOT=%USERPROFILE%\Downloads\Godot_v4.6.3-stable_win64.exe"
)

if not exist "%GODOT%" (
  echo Godot 4.6.3 was not found in your Downloads folder.
  echo Open Godot manually and import this project folder:
  echo %PROJECT_DIR%
  pause
  exit /b 1
)

"%GODOT%" --path "%PROJECT_DIR%" --scene res://scenes/main.tscn
