@echo off
setlocal enabledelayedexpansion
if not exist ssids.txt (
  call scan.bat
)
if not exist ssids.txt (
  echo No SSIDs to connect.
  exit /b 1
)
echo Available ESP32 APs:
type ssids.txt
set /p choice=Enter number to connect: 
for /f "usebackq tokens=1,2 delims=|" %%A in ('findstr /B "%choice%|" ssids.txt') do (
  set "SSID=%%B"
)
if "%SSID%"=="" (
  echo Invalid selection.
  exit /b 1
)
rem get password from config
set "password="
if exist config.json (
  for /f "usebackq tokens=2 delims=:" %%A in (`findstr /C:"\"ap_password\"" config.json`) do (
    set p=%%A
    set p=!p:"=! 
    for /f "delims= " %%B in ("!p!") do set "password=%%B"
  )
)
if "%password%"=="" (
  set /p password=Enter AP password (leave blank for open): 
)
echo Connecting to %SSID% ...
rem create profile if password provided
if "%password%"=="" (
  netsh wlan connect ssid="%SSID%" name="%SSID%" 2>nul || (
    echo Unable to connect without profile. Creating open profile...
    call :create_profile "%SSID%" ""
    netsh wlan add profile filename="%temp%\esp32_profile.xml" user=current >nul
    netsh wlan connect name="%SSID%" ssid="%SSID%"
  )
) else (
  call :create_profile "%SSID%" "%password%"
  netsh wlan add profile filename="%temp%\esp32_profile.xml" user=current >nul
  netsh wlan connect name="%SSID%" ssid="%SSID%"
)
echo Waiting for connection...
timeout /t 5 >nul
netsh wlan show interfaces | findstr /I "SSID" 
echo ESP32 IP (default): 
for /f "tokens=2 delims=:" %%I in ('findstr /C:"\"esp32_ip\"" config.json 2^>nul') do set ip=%%I
if defined ip (
  set ip=%ip:"=%
  echo %ip%
) else (
  echo 192.168.4.1
)
exit /b

:create_profile
rem %1 SSID, %2 password (empty for open)
setlocal EnableDelayedExpansion
set "ssid=%~1"
set "pwd=%~2"
set "file=%temp%\esp32_profile.xml"
if "%pwd%"=="" (
  >"%file%" echo ^<?xml version="1.0"^?^>
  >>"%file%" echo ^<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"^>
  >>"%file%" echo   ^<name^>!ssid!^</name^>
  >>"%file%" echo   ^<SSIDConfig^>
  >>"%file%" echo     ^<SSID^>^<name^>!ssid!^</name^>^</SSID^>
  >>"%file%" echo   ^</SSIDConfig^>
  >>"%file%" echo   ^<connectionType^>ESS^</connectionType^>
  >>"%file%" echo   ^<connectionMode^>auto^</connectionMode^>
  >>"%file%" echo   ^<MSM^>
  >>"%file%" echo     ^<security^>
  >>"%file%" echo       ^<authEncryption^>
  >>"%file%" echo         ^<authentication^>open^</authentication^>
  >>"%file%" echo         ^<encryption^>none^</encryption^>
  >>"%file%" echo         ^<useOneX^>false^</useOneX^>
  >>"%file%" echo       ^</authEncryption^>
  >>"%file%" echo     ^</security^>
  >>"%file%" echo   ^</MSM^>
  >>"%file%" echo ^</WLANProfile^>
) else (
  >"%file%" echo ^<?xml version="1.0"^?^>
  >>"%file%" echo ^<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"^>
  >>"%file%" echo   ^<name^>!ssid!^</name^>
  >>"%file%" echo   ^<SSIDConfig^>
  >>"%file%" echo     ^<SSID^>^<name^>!ssid!^</name^>^</SSID^>
  >>"%file%" echo   ^</SSIDConfig^>
  >>"%file%" echo   ^<connectionType^>ESS^</connectionType^>
  >>"%file%" echo   ^<connectionMode^>auto^</connectionMode^>
  >>"%file%" echo   ^<MSM^>
  >>"%file%" echo     ^<security^>
  >>"%file%" echo       ^<authEncryption^>
  >>"%file%" echo         ^<authentication^>WPA2PSK^</authentication^>
  >>"%file%" echo         ^<encryption^>AES^</encryption^>
  >>"%file%" echo         ^<useOneX^>false^</useOneX^>
  >>"%file%" echo       ^</authEncryption^>
  >>"%file%" echo       ^<sharedKey^>
  >>"%file%" echo         ^<keyType^>passPhrase^</keyType^>
  >>"%file%" echo         ^<protected^>false^</protected^>
  >>"%file%" echo         ^<keyMaterial^>!pwd!^</keyMaterial^>
  >>"%file%" echo       ^</sharedKey^>
  >>"%file%" echo     ^</security^>
  >>"%file%" echo   ^</MSM^>
  >>"%file%" echo ^</WLANProfile^>
)
endlocal & goto :eof
