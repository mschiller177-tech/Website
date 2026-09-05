@echo off
REM Richtet den Agentur-MCP-Server in Claude Desktop ein.
REM Sucht Python selbst und ruft damit setup.py auf. Doppelklick genuegt.
setlocal

echo.
echo Agentur-MCP - Einrichtung fuer Claude Desktop
echo ============================================
echo.

set "SETUP=%~dp0setup.py"
if not exist "%SETUP%" (
  echo FEHLER: setup.py nicht gefunden neben dieser Datei.
  echo Erwartet: %SETUP%
  echo Das Repository ist unvollstaendig. Bitte neu klonen.
  goto :ende
)

REM Python suchen - erst der offizielle Launcher, dann PATH, dann uebliche Orte.
set "PY="
py -3 -c "import sys" >nul 2>&1 && set "PY=py -3"
if not defined PY python -c "import sys" >nul 2>&1 && set "PY=python"
if not defined PY python3 -c "import sys" >nul 2>&1 && set "PY=python3"

if not defined PY (
  for %%V in (313 312 311 310 39 38) do (
    if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
      set "PY=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
    )
    if not defined PY if exist "C:\Python%%V\python.exe" set "PY=C:\Python%%V\python.exe"
  )
)

if not defined PY (
  echo FEHLER: Es wurde kein funktionierendes Python gefunden.
  echo.
  echo Python installieren: https://www.python.org/downloads/windows/
  echo Beim Installieren unbedingt "Add python.exe to PATH" ankreuzen.
  echo.
  echo Hinweis: Ein blosses "python" ohne Ausgabe ist die Microsoft-Store-
  echo Verknuepfung und kein echtes Python.
  goto :ende
)

echo Gefundenes Python: %PY%
echo.

REM Projektordner optional als erstes Argument, sonst nachfragen.
set "PROJEKT=%~1"
if "%PROJEKT%"=="" (
  set /p "PROJEKT=Projektordner fuer deine App (Enter zum Ueberspringen): "
)

if "%PROJEKT%"=="" (
  %PY% "%SETUP%"
) else (
  %PY% "%SETUP%" --projekt "%PROJEKT%"
)

:ende
echo.
pause
endlocal
