@echo off
rem St. Peter OS: runs once as SYSTEM at the end of Windows setup, before the first sign-in.
curl.exe -s -m 5 -X POST http://10.0.2.100/phase/configure >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\StPeter\setup-system.ps1 > C:\StPeter\setup-system.log 2>&1
