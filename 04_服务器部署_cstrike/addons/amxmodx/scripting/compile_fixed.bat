@echo off
setlocal
cd /d "%~dp0"
if not exist compiled mkdir compiled
amxxpc.exe HnsAISignup.sma
if errorlevel 1 goto :error
amxxpc.exe HnsMatchSkin.sma
if errorlevel 1 goto :error
copy /y HnsAISignup.amxx compiled\HnsAISignup.amxx >nul 2>&1
copy /y HnsMatchSkin.amxx compiled\HnsMatchSkin.amxx >nul 2>&1
if exist HnsAISignup.amxx copy /y HnsAISignup.amxx . >nul 2>&1
if exist HnsMatchSkin.amxx copy /y HnsMatchSkin.amxx . >nul 2>&1
echo.
echo [OK] HnsAISignup and HnsMatchSkin compiled.
pause
exit /b 0
:error
echo.
echo [ERROR] Compile failed. Check the compiler output above.
pause
exit /b 1
