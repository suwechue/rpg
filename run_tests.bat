@echo off
rem Double-click to check that the project loads and the core tests pass.
rem Results are written to tools\load_check.log and tools\test_results.log
cd /d "%~dp0"
set GODOT=C:\Users\itzju\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
echo Checking the project loads...
"%GODOT%" --headless --path . --quit > tools\load_check.log 2>&1
echo exit code %errorlevel% >> tools\load_check.log
echo Running tests...
"%GODOT%" --headless --path . -s res://tests/run_tests.gd > tools\test_results.log 2>&1
echo exit code %errorlevel% >> tools\test_results.log
type tools\test_results.log
echo.
echo Done. Results saved in the tools folder.
timeout /t 5 >nul
