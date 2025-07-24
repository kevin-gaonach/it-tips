@echo off
set type=.ps1
set name=%~n0
set file=%name%%type%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0%file%"
