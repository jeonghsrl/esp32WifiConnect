@echo off
setlocal enabledelayedexpansion

REM ===== ログファイルにすべての出力を記録 =====
set "logfile=%USERPROFILE%\Desktop\esp32_connect.log"
if exist "%logfile%" del "%logfile%"

echo. > "%logfile%"
echo ========== ESP32 Connect - Debug Log ========== >> "%logfile%"
echo Timestamp: %date% %time% >> "%logfile%"
echo. >> "%logfile%"

cls
echo.
echo ========== ESP32 Wi-Fi Connect Tool ==========
echo.
echo All output will be saved to:
echo %logfile%
echo.
echo =========================================
echo.

REM ===== メイン処理開始 =====
call :main
set "exit_code=!errorlevel!"

echo.
echo ===== Execution Complete =====
echo Exit code: %exit_code%
echo Log file: %logfile%
echo.
echo Waiting 30 seconds before closing...
timeout /t 30

REM ===== ログを開く =====
start "" "%logfile%"

exit /b %exit_code%

:main
if not exist ssids.txt (
  call scan.bat >> "%logfile%" 2>&1
)
if not exist ssids.txt (
  echo No SSIDs to connect. >> "%logfile%"
  echo No SSIDs to connect.
  exit /b 1
)

echo. >> "%logfile%"
echo ========== AVAILABLE SSIDs ========== >> "%logfile%"
type ssids.txt >> "%logfile%"
echo. >> "%logfile%"

echo.
echo Available ESP32 APs:
type ssids.txt
echo.
set /p choice=Enter number to connect: 

echo Input number: %choice% >> "%logfile%"

for /f "usebackq tokens=1,2 delims=|" %%A in ('findstr /B "%choice%|" ssids.txt') do (
  set "SSID=%%B"
)

if "%SSID%"=="" (
  echo Invalid selection: %choice% >> "%logfile%"
  echo Invalid selection.
  exit /b 1
)

echo. >> "%logfile%"
echo ========== DEBUG INFO ========== >> "%logfile%"
echo Selected SSID: %SSID% >> "%logfile%"
echo. >> "%logfile%"

echo Selected: %SSID%

REM ===== パスワード取得 =====
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
  echo Password: (none - open AP) >> "%logfile%"
  echo Password: (none - open AP)
) else (
  echo Password: (set) >> "%logfile%"
  echo Password: (set)
)
echo. >> "%logfile%"

echo. >> "%logfile%"
echo ========== CONNECTION PROCESS ========== >> "%logfile%"
echo.
echo Connecting to %SSID% ...
echo Connecting to %SSID% ... >> "%logfile%"

REM ===== プロファイル作成と接続 =====
if "%password%"=="" (
  echo [*] Attempting direct connection (no profile needed)... >> "%logfile%"
  echo Attempting direct connection...
  netsh wlan connect ssid="%SSID%" name="%SSID%" >> "%logfile%" 2>&1
  if !errorlevel! equ 0 (
    echo [OK] Direct connection succeeded >> "%logfile%"
    echo Direct connection succeeded
  ) else (
    echo [FAIL] Direct connection failed, creating open profile... >> "%logfile%"
    echo Creating open profile...
    call :create_profile "%SSID%" ""
    echo [*] Adding profile to Windows... >> "%logfile%"
    netsh wlan add profile filename="%temp%\esp32_profile.xml" user=current >> "%logfile%" 2>&1
    echo [*] Connecting via profile... >> "%logfile%"
    netsh wlan connect name="%SSID%" ssid="%SSID%" >> "%logfile%" 2>&1
  )
) else (
  echo [*] Creating WPA2 profile... >> "%logfile%"
  echo Creating WPA2 profile...
  call :create_profile "%SSID%" "%password%"
  echo [*] Adding profile to Windows... >> "%logfile%"
  netsh wlan add profile filename="%temp%\esp32_profile.xml" user=current >> "%logfile%" 2>&1
  echo [*] Connecting via profile... >> "%logfile%"
  netsh wlan connect name="%SSID%" ssid="%SSID%" >> "%logfile%" 2>&1
)

echo. >> "%logfile%"
echo Waiting 3 seconds for connection to establish...
echo Waiting 3 seconds for connection to establish... >> "%logfile%"
timeout /t 3 >nul

echo. >> "%logfile%"
echo ========== CONNECTION STATUS (after 3 seconds) ========== >> "%logfile%"
echo.
echo Checking connection status...
netsh wlan show interfaces >> "%logfile%" 2>&1
netsh wlan show interfaces
echo. >> "%logfile%"

echo. >> "%logfile%"
echo ========== CONFIGURING STATIC IP ========== >> "%logfile%"
echo.
echo Configuring static IP (192.168.4.x/24)...
echo Configuring static IP (192.168.4.x/24)... >> "%logfile%"

REM ===== ネットワークアダプター検出 =====
set "adapter_name="
for /f "skip=4 tokens=*" %%A in ('netsh wlan show interfaces') do (
  set "line=%%A"
  if "!line:Name=!" neq "!line!" (
    for /f "tokens=3,*" %%B in ("!line!") do (
      set "adapter_name=%%C"
      goto :got_adapter
    )
  )
)

:got_adapter
if not defined adapter_name (
  for /f "skip=4 tokens=*" %%A in ('netsh wlan show interfaces') do (
    set "adapter_name=%%A"
    goto :got_adapter2
  )
)

:got_adapter2
if defined adapter_name (
  echo [OK] Found adapter: !adapter_name! >> "%logfile%"
  echo Found adapter: !adapter_name!
  
  REM ===== ランダムIP生成 =====
  set /a client_ip=10+!random! %% 190
  set "client_ip=192.168.4.!client_ip!"
  echo [*] Setting static IP: !client_ip! >> "%logfile%"
  echo Setting static IP: !client_ip!
  echo. >> "%logfile%"
  
  REM ===== 静的IP設定 =====
  echo [*] Running: netsh interface ip set address name="!adapter_name!" static !client_ip! 255.255.255.0 192.168.4.1 >> "%logfile%"
  netsh interface ip set address name="!adapter_name!" static !client_ip! 255.255.255.0 192.168.4.1 >> "%logfile%" 2>&1
  
  if !errorlevel! equ 0 (
    echo [OK] Static IP set successfully >> "%logfile%"
    echo Static IP set successfully
  ) else (
    echo [ERROR] Failed to set static IP (errorlevel: !errorlevel!) >> "%logfile%"
    echo ERROR: Failed to set static IP
  )
  
  echo. >> "%logfile%"
  echo [*] Waiting 2 seconds for IP to be assigned... >> "%logfile%"
  echo Waiting 2 seconds for IP to be assigned...
  timeout /t 2 >nul
  
  echo. >> "%logfile%"
  echo [*] Waiting 10 seconds for interface to stabilize... >> "%logfile%"
  echo Waiting 10 seconds for interface to stabilize...
  timeout /t 10 >nul
  
  echo. >> "%logfile%"
  echo ========== FINAL NETWORK STATUS ========== >> "%logfile%"
  netsh wlan show interfaces >> "%logfile%" 2>&1
  echo. >> "%logfile%"
  echo ========== IPv4 ADDRESS ========== >> "%logfile%"
  netsh interface ipv4 show address "!adapter_name!" >> "%logfile%" 2>&1
  echo. >> "%logfile%"
  
  echo.
  echo Final network configuration:
  netsh wlan show interfaces
  echo.
  echo IPv4 Address:
  netsh interface ipv4 show address "!adapter_name!"
  echo.
) else (
  echo [ERROR] Could not find Wi-Fi adapter >> "%logfile%"
  echo ERROR: Could not find Wi-Fi adapter
  echo. >> "%logfile%"
  echo Available adapters: >> "%logfile%"
  netsh wlan show interfaces >> "%logfile%" 2>&1
  echo.
  echo Available adapters:
  netsh wlan show interfaces
  exit /b 1
)

REM ===== ESP32 IP表示 =====
set "cfg_ip="
for /f "tokens=2 delims=:" %%I in ('findstr /C:"\"esp32_ip\"" config.json 2^>nul') do set cfg_ip=%%I
if defined cfg_ip (
  set cfg_ip=!cfg_ip:"=!
  set cfg_ip=!cfg_ip: =!
  set cfg_ip=!cfg_ip:,=!
  echo. >> "%logfile%"
  echo Configured ESP32 IP: !cfg_ip! >> "%logfile%"
  echo You can now access ESP32 at: http://!cfg_ip!/ >> "%logfile%"
  echo.
  echo Configured ESP32 IP: !cfg_ip!
  echo You can now access ESP32 at: http://!cfg_ip!/
)

echo. >> "%logfile%"
echo ========== CONNECTION COMPLETED ========== >> "%logfile%"
echo. >> "%logfile%"
echo If connection failed, check: >> "%logfile%"
echo 1. ESP32 is powered on and SoftAP is running >> "%logfile%"
echo 2. SSID is broadcasting (check ESP32 serial output) >> "%logfile%"
echo 3. No password mismatch >> "%logfile%"
echo 4. Network adapter name (shown above) >> "%logfile%"
echo 5. Check log file for detailed errors >> "%logfile%"
echo. >> "%logfile%"

exit /b 0

:create_profile
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
