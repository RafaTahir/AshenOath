@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\deploy_web_update.ps1" %*
