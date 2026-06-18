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

timeout /t 3 >nul

echo Configuring static IP (192.168.4.x/24)...
rem Get the Wi-Fi adapter name from netsh
for /f "tokens=2" %%A in ('netsh wlan show interfaces ^| find "Name"') do (
  set "adapter_name=%%A"
  goto :got_adapter
)

:got_adapter
if defined adapter_name (
  echo Found adapter: !adapter_name!
  
  rem Get a random IP in the range 192.168.4.10-192.168.4.200
  set /a client_ip=10+!random! %% 190
  set "client_ip=192.168.4.!client_ip!"
  echo Setting static IP: !client_ip!
  
  rem Set static IP using netsh
  netsh interface ip set address name="!adapter_name!" static !client_ip! 255.255.255.0 192.168.4.1
  
  timeout /t 2 >nul
  
  echo Waiting for interface to stabilize (10s)...
  timeout /t 10 >nul
  
  rem Verify IP configuration
  for /f "tokens=*" %%I in ('netsh interface ip show address "!adapter_name!" ^| find "192.168.4"') do (
    set "ip_result=%%I"
  )
  
  if defined ip_result (
    echo Successfully configured static IP!
    echo !ip_result!
  ) else (
    echo Warning: Could not verify IP configuration
  )
) else (
  echo ERROR: Could not find Wi-Fi adapter
  exit /b 1
)

rem show configured esp32_ip from config if present
set "cfg_ip="
for /f "tokens=2 delims=:" %%I in ('findstr /C:"\"esp32_ip\"" config.json 2^>nul') do set cfg_ip=%%I
if defined cfg_ip (
  set cfg_ip=!cfg_ip:"=!
  set cfg_ip=!cfg_ip: =!
  set cfg_ip=!cfg_ip:,=!
  echo.
  echo Configured ESP32 IP: !cfg_ip!
  echo.
  echo You can now access ESP32 at: http://!cfg_ip!/
)

echo.
echo Connection completed successfully!
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
