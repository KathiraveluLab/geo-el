@echo off
setlocal

echo [geo-el] Checking Windows prerequisites (Erlang/OTP and Elixir)...

where erl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    if not exist "C:\Program Files\Erlang OTP\bin\erl.exe" (
        echo [geo-el] Installing Erlang/OTP via winget...
        winget install --id=Erlang.ErlangOTP -e --accept-package-agreements --accept-source-agreements
    )
)

where mix >nul 2>nul
if %ERRORLEVEL% neq 0 (
    if not exist "C:\Program Files\Elixir\bin\mix.bat" (
        echo [geo-el] Installing Elixir via winget...
        winget install --id=Elixir.Elixir -e --accept-package-agreements --accept-source-agreements
    )
)

echo [geo-el] Configuring User PATH and PowerShell ExecutionPolicy...
powershell -NoProfile -Command "$ErrorActionPreference = 'SilentlyContinue'; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; $u = [System.Environment]::GetEnvironmentVariable('Path','User'); $dirs = @('C:\Program Files\Erlang OTP\bin', 'C:\Program Files\Elixir\bin'); foreach ($d in $dirs) { if ((Test-Path $d) -and ($u -notlike \"*$d*\")) { $u = \"$u;$d\" } }; [System.Environment]::SetEnvironmentVariable('Path', $u, 'User')"

set "PATH=C:\Program Files\Erlang OTP\bin;C:\Program Files\Elixir\bin;%PATH%"

echo [geo-el] Initializing Hex and Rebar package managers...
call "C:\Program Files\Elixir\bin\mix.bat" local.hex --force
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

call "C:\Program Files\Elixir\bin\mix.bat" local.rebar --force
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [geo-el] Running mix setup...
call "C:\Program Files\Elixir\bin\mix.bat" setup
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [geo-el] Running mix precommit verification...
call "C:\Program Files\Elixir\bin\mix.bat" precommit
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [geo-el] Setup and verification completed.
echo [geo-el] NOTE: If running inside an existing PowerShell window, refresh your session PATH with:
echo [geo-el]   $env:Path = "C:\Program Files\Erlang OTP\bin;C:\Program Files\Elixir\bin;" + $env:Path
endlocal
