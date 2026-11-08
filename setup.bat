@echo off
setlocal EnableDelayedExpansion

echo [geo-el] Checking Windows prerequisites (Erlang/OTP and Elixir)...

where erl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [geo-el] Erlang/OTP not found on PATH. Installing via winget...
    winget install --id=Erlang.ErlangOTP -e --accept-package-agreements --accept-source-agreements
    if !ERRORLEVEL! neq 0 (
        where choco >nul 2>nul
        if !ERRORLEVEL! equ 0 (
            choco install erlang -y
        ) else (
            echo [geo-el] ERROR: Failed to install Erlang/OTP automatically. Please run in an Administrator terminal.
            exit /b 1
        )
    )
) else (
    echo [geo-el] Erlang/OTP is already available.
)

where mix >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [geo-el] Elixir not found on PATH. Installing via winget...
    winget install --id=Elixir.Elixir -e --accept-package-agreements --accept-source-agreements
    if !ERRORLEVEL! neq 0 (
        where choco >nul 2>nul
        if !ERRORLEVEL! equ 0 (
            choco install elixir -y
        ) else (
            echo [geo-el] ERROR: Failed to install Elixir automatically. Please run in an Administrator terminal.
            exit /b 1
        )
    )
) else (
    echo [geo-el] Elixir is already available.
)

echo [geo-el] Refreshing session PATH for Erlang and Elixir...
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$m = [System.Environment]::GetEnvironmentVariable('Path','Machine'); $u = [System.Environment]::GetEnvironmentVariable('Path','User'); $extra = @(); Get-ChildItem -Path 'C:\Program Files' -Filter 'erl*' -Directory -ErrorAction SilentlyContinue | ForEach-Object { if (Test-Path (Join-Path $_.FullName 'bin')) { $extra += (Join-Path $_.FullName 'bin') } }; Get-ChildItem -Path 'C:\Program Files', 'C:\Program Files (x86)' -Filter 'Elixir*' -Directory -ErrorAction SilentlyContinue | ForEach-Object { if (Test-Path (Join-Path $_.FullName 'bin')) { $extra += (Join-Path $_.FullName 'bin') } }; ($m + ';' + $u + ';' + ($extra -join ';'))"`) do (
    set "PATH=%%I"
)

where mix >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [geo-el] ERROR: mix command is still not reachable on PATH. Please open a new terminal window and re-run setup.bat.
    exit /b 1
)

echo [geo-el] Initializing Hex and Rebar package managers...
call mix local.hex --force
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

call mix local.rebar --force
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [geo-el] Fetching project dependencies via mix setup...
call mix setup
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [geo-el] Setup completed. Run 'mix precommit' to verify or 'mix phx.server' to start the application.
endlocal

