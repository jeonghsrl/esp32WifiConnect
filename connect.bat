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

echo Waiting for IP assignment (30s timeout)...
set "ip="
for /L %%N in (1,1,6) do (
  rem poll interfaces output
  netsh wlan show interfaces > "%temp%\iface.txt"
  rem extract IPv4-like tokens from file
  for /f "tokens=* delims=" %%L in ('type "%temp%\iface.txt"') do (
    for %%T in (%%L) do (
      echo %%T | findstr /R "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
      if not errorlevel 1 (
        for /f "tokens=1" %%X in ('echo %%T ^| findstr /R "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"') do (
          set "candidate=%%X"
          rem exclude link-local and invalid addresses
          echo !candidate! | findstr /B "169.254" >nul
          if errorlevel 1 (
            echo !candidate! | findstr /C:"0.0.0.0" >nul
            if errorlevel 1 (
              rem basic octet check
              for /f "tokens=1-4 delims=." %%a in ("!candidate!") do (
                if %%a LEQ 255 if %%b LEQ 255 if %%c LEQ 255 if %%d LEQ 255 (
                  set "ip=!candidate!" & goto :got_ip
                )
              )
            )
          )
        )
      )
    )
  )
  timeout /t 5 >nul
)
:got_ip
if defined ip (
  echo Connected. IP: !ip!
) else (
  echo Connection attempt timed out -- IP not found.
)

rem show configured esp32_ip from config if present
for /f "tokens=2 delims=:" %%I in ('findstr /C:"\"esp32_ip\"" config.json 2^>nul') do set cfg_ip=%%I
if defined cfg_ip (
  set cfg_ip=!cfg_ip:"=!
  echo Configured ESP32 IP: !cfg_ip!
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
