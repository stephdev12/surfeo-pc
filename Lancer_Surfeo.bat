@echo off
:: BatchGotAdmin
:-------------------------------------
REM --> Verification des privileges Administrateur (Requis pour Wintun et les tables de routage)
IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

REM --> Demande d'elevation UAC automatique si non-administrateur
if '%errorlevel%' NEQ '0' (
    echo [SURFEO] Demande des privileges administrateur pour configurer le reseau virtuel Wintun...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------

echo ====================================================
echo        SURFEO SECURE TUNNEL - WINDOWS EDITION
echo ====================================================
echo Demarrage du moteur reseau securise...

tasklist /FI "IMAGENAME eq surfeo-core.exe" 2>NUL | find /I /N "surfeo-core.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [INFO] Moteur surfeo-core deja actif.
) else (
    start "" /B "%~dp0surfeo-core.exe"
    timeout /t 1 /nobreak >nul
)

echo Lancement de l'interface Surfeo...
start "" "%~dp0surfeo_pc.exe"
