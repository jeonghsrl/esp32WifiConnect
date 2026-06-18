@echo off
setlocal enabledelayedexpansion
set CONFIG=config.json
set "prefix=ESP32"
if exist %CONFIG% (
  for /f "usebackq tokens=2 delims=:" %%A in (`findstr /C:"\"ssid_prefix\"" %CONFIG%`) do (
    set p=%%A
    rem remove quotes and spaces
    set p=!p:"=!
    set p=!p:,=! 
    for /f "delims= " %%B in ("!p!") do set "prefix=%%B"
  )
)
echo Using SSID prefix: %prefix%
echo Scanning Wi-Fi networks...
netsh wlan show networks mode=bssid > .\networks_raw.txt
del ssids.txt 2>nul
set /a idx=0
for /f "tokens=1,* delims=:" %%A in ('findstr /R /C:"SSID [0-9]* :" .\networks_raw.txt') do (
  set "ssid=%%B"
  rem trim leading spaces
  for /f "tokens=* delims= " %%C in ("!ssid!") do set "ssid=%%C"
  rem check prefix
  echo !ssid! | findstr /I /B "%prefix%" >nul
  if !errorlevel! EQU 0 (
    set /a idx+=1
    echo !idx!^|!ssid!>> ssids.txt
  )
)
if %idx%==0 (
  echo No ESP32 SSID found.
) else (
  echo Found %idx% SSID(s):
  type ssids.txt
)
endlocal
