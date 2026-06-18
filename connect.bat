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
echo.
echo ========== DEBUG INFO ==========
echo Selected SSID: %SSID%
echo.

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

if "%password%"=="" (
  echo Password: (none - open AP)
) else (
  echo Password: (set)
)
echo.

echo Connecting to %SSID% ...
echo Creating Wi-Fi profile...
rem create profile if password provided
if "%password%"=="" (
  echo Attempting direct connection (no profile needed)...
  netsh wlan connect ssid="%SSID%" name="%SSID%" 2>nul && (
    echo Direct connection succeeded
  ) || (
    echo Direct connection failed, creating open profile...
    call :create_profile "%SSID%" ""
    echo Adding profile to Windows...
    netsh wlan add profile filename="%temp%\esp32_profile.xml" user=current
    echo Connecting via profile...
    netsh wlan connect name="%SSID%" ssid="%SSID%"
  )
) else (
  echo Creating WPA2 profile...
  call :create_profile "%SSID%" "%password%"
  echo Adding profile to Windows...
  netsh wlan add profile filename="%temp%\esp32_profile.xml" user=current
  echo Connecting via profile...
  netsh wlan connect name="%SSID%" ssid="%SSID%"
)

echo.
echo Waiting 3 seconds for connection to establish...
timeout /t 3 >nul

echo.
echo Checking connection status...
netsh wlan show interfaces

echo.
echo Configuring static IP (192.168.4.x/24)...
rem Get the Wi-Fi adapter name from netsh
set "adapter_name="
for /f "skip=3 tokens=1,*" %%A in ('netsh wlan show interfaces') do (
  if not "%%B"=="" (
    set "adapter_name=%%A"
    goto :got_adapter
  )
)

:got_adapter
if defined adapter_name (
  echo Found adapter: !adapter_name!
  
  rem Get a random IP in the range 192.168.4.10-192.168.4.200
  set /a client_ip=10+!random! %% 190
  set "client_ip=192.168.4.!client_ip!"
  echo Setting static IP: !client_ip!
  echo.
  
  rem Set static IP using netsh
  echo Running: netsh interface ip set address name="!adapter_name!" static !client_ip! 255.255.255.0 192.168.4.1
  netsh interface ip set address name="!adapter_name!" static !client_ip! 255.255.255.0 192.168.4.1
  
  if !errorlevel! equ 0 (
    echo Static IP set successfully
  ) else (
    echo ERROR: Failed to set static IP (errorlevel: !errorlevel!)
  )
  
  echo.
  echo Waiting 2 seconds for IP to be assigned...
  timeout /t 2 >nul
  
  echo.
  echo Waiting 10 seconds for interface to stabilize...
  timeout /t 10 >nul
  
  echo.
  echo ========== FINAL NETWORK STATUS ==========
  netsh wlan show interfaces
  echo.
  echo ========== IPv4 ADDRESS ==========
  netsh interface ipv4 show address "!adapter_name!"
  echo.
) else (
  echo ERROR: Could not find Wi-Fi adapter
  echo.
  echo Available adapters:
  netsh wlan show interfaces
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
  echo You can now access ESP32 at: http://!cfg_ip!/
)

echo.
echo ========== CONNECTION COMPLETED ==========
echo If connection failed, check:
echo 1. ESP32 is powered on and SoftAP is running
echo 2. SSID is broadcasting (check ESP32 serial output)
echo 3. No password mismatch
echo 4. Network adapter name (shown above)
echo.
pause
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
