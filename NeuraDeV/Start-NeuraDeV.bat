@echo off
chcp 65001 >nul
title NeuraDeV — Starter
cd /d "%~dp0"

echo.
echo  ███╗   ██╗███████╗██╗   ██╗██████╗  █████╗ ██████╗ ███████╗██╗   ██╗
echo  ████╗  ██║██╔════╝██║   ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝██║   ██║
echo  ██╔██╗ ██║█████╗  ██║   ██║██████╔╝███████║██║  ██║█████╗  ██║   ██║
echo  ██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██╔══██║██║  ██║██╔══╝  ╚██╗ ██╔╝
echo  ██║ ╚████║███████╗╚██████╔╝██║  ██║██║  ██║██████╔╝███████╗ ╚████╔╝
echo  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝  ╚═══╝
echo.
echo  AI Powered Development — Starter
echo  --------------------------------------------------------------------
echo.

where dotnet >nul 2>&1
if errorlevel 1 (
    echo  [!] .NET wurde nicht gefunden.
    goto :need_sdk
)

dotnet --list-sdks | findstr /B "8." >nul 2>&1
if errorlevel 1 (
    echo  [!] .NET 8 SDK fehlt. Installierte SDKs:
    dotnet --list-sdks
    goto :need_sdk
)

echo  [OK] .NET 8 SDK gefunden.
echo  [.] Baue NeuraDeV (Release)...
echo.

dotnet build src/NeuraDeV -c Release
if errorlevel 1 (
    echo.
    echo  [X] Build fehlgeschlagen. Bitte den Output oben kopieren und melden.
    pause
    exit /b 1
)

echo.
echo  [OK] Build erfolgreich. Starte NeuraDeV...
echo.
start "" dotnet run --project src/NeuraDeV -c Release --no-build
exit /b 0


:need_sdk
echo.
echo  --------------------------------------------------------------------
echo  Bitte installiere einmalig das .NET 8 SDK.
echo.
echo  Direkt-Download (Windows x64):
echo    https://dotnet.microsoft.com/download/dotnet/8.0
echo.
echo  Auf der Seite: "SDK x64" Button fuer Windows klicken.
echo  Nach der Installation diese Datei erneut doppelklicken.
echo  --------------------------------------------------------------------
echo.
start https://dotnet.microsoft.com/download/dotnet/8.0
pause
exit /b 1
