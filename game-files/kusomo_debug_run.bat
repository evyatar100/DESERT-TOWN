@echo off
rem TG49: starts the game in debug mode (F9 works) and keeps the engine output in mkxp_stdout.log.
rem Send back mkxp_stdout.log and kusomo_trace.log from this folder after the game closes.
cd /d "%~dp0"
set MKXPZ_WINDOWS_CONSOLE=0
echo ==== %date% %time% >> "%~dp0mkxp_stdout.log"
"%~dp0Game.exe" debug >> "%~dp0mkxp_stdout.log" 2>&1
echo ==== exit code %errorlevel% at %time% >> "%~dp0mkxp_stdout.log"
