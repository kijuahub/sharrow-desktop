@echo off
setlocal EnableExtensions
cd /d "%~dp0"

where gh >nul 2>&1
if errorlevel 1 (
  echo Install GitHub CLI: https://cli.github.com
  pause
  exit /b 1
)

git status --porcelain > "%TEMP%\sharrow-status.txt"
for %%A in ("%TEMP%\sharrow-status.txt") do set SIZE=%%~zA
if not "%SIZE%"=="0" (
  git add -A
  git -c user.name=kijuahub -c user.email=kijuahub@users.noreply.github.com commit -m "Build desktop and iOS packages"
  if errorlevel 1 (
    echo Commit failed.
    pause
    exit /b 1
  )
)

git push origin HEAD:main
if errorlevel 1 (
  echo Push to main failed.
  pause
  exit /b 1
)

gh workflow run build.yml --ref main
if errorlevel 1 (
  echo Could not start the build.
  pause
  exit /b 1
)

echo Waiting for the build to appear...
ping -n 8 127.0.0.1 >nul
gh run list --workflow build.yml --limit 1 --json databaseId --jq ".[0].databaseId" > "%TEMP%\sharrow-run.txt"
set /p RUN=<"%TEMP%\sharrow-run.txt"
if "%RUN%"=="" (
  echo Build run was not found.
  pause
  exit /b 1
)

echo Build %RUN%
gh run watch %RUN% --exit-status
set BUILD_ERR=%ERRORLEVEL%

if not exist dist\incoming mkdir dist\incoming
gh run download %RUN% -n windows -D dist\incoming
gh run download %RUN% -n linux -D dist\incoming
gh run download %RUN% -n ios -D dist\incoming
if not exist dist mkdir dist
move /Y "dist\incoming\*" dist\ >nul
rmdir dist\incoming 2>nul

echo.
echo Files in dist:
dir /b dist
if not "%BUILD_ERR%"=="0" echo Build failed. Logs: gh run view %RUN%
pause
exit /b %BUILD_ERR%
