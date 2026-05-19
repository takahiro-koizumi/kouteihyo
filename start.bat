@echo off
cd /d "%~dp0"
start "" http://localhost:8090/
powershell -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
