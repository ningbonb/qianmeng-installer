@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "QIANMENG_INSTALLER_VERSION=0.1.0"
set "STATE_DIR=%USERPROFILE%\.qianmeng-installer"
set "LOG_FILE=%STATE_DIR%\qianmeng.log"
set "LOGO_URL=https://sales.ws.126.net/minisite/2026/0901/1788255726_logo.png"
set "REPO=ningbonb/qianmeng-installer"

set "PENDING_UPDATE_APPLIED="
if exist "%~dp0qianmeng.bat.new" call :apply_pending_update
if defined PENDING_UPDATE_APPLIED exit /b 0
call :prompt_update
start "" /b powershell -NoProfile -WindowStyle Hidden -Command "$ErrorActionPreference='SilentlyContinue'; $tag=(Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/releases/latest' -Headers @{ 'User-Agent'='qianmeng-installer' } -TimeoutSec 5).tag_name; if($tag){ New-Item -ItemType Directory -Force -Path '%STATE_DIR%' ^| Out-Null; Set-Content -NoNewline -Encoding ascii -Path '%STATE_DIR%\latest_tag' -Value $tag }"

if exist "%APPDATA%\npm" set "PATH=%APPDATA%\npm;%PATH%"
call :find_dsh
if errorlevel 1 goto install
goto setup

:install
echo ================================================================
echo    千梦安装器
echo ================================================================
where node >nul 2>nul
if errorlevel 1 goto install_node
for /f "delims=" %%v in ('node -v 2^>nul') do set "NVER=%%v"
set "NVER=%NVER:v=%"
call :node_version_ok
if not errorlevel 1 goto install_pnpm

:install_node
echo 正在安装 Node.js…
where winget >nul 2>nul
if errorlevel 1 echo 未找到 winget，请从 https://nodejs.org 安装 Node.js 后重新运行。
if errorlevel 1 goto fail
winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto fail
set "PATH=%ProgramFiles%\nodejs;%PATH%"
for /f "delims=" %%v in ('node -v 2^>nul') do set "NVER=%%v"
set "NVER=%NVER:v=%"
call :node_version_ok
if errorlevel 1 echo Node.js 安装后请关闭窗口并重新运行本脚本。
if errorlevel 1 goto fail

:install_pnpm
echo 正在安装 pnpm…
call npm install -g pnpm
if errorlevel 1 goto fail
echo 正在安装 dsh…
call npm install -g @deepseek-ai/dsh
if errorlevel 1 goto fail
if exist "%APPDATA%\npm" set "PATH=%APPDATA%\npm;%PATH%"
call :find_dsh
if errorlevel 1 goto fail

:setup
call :ensure_product_setup
if errorlevel 1 goto fail
goto choose_mode

:apply_pending_update
findstr /c:"@echo off" "%~dp0qianmeng.bat.new" >nul 2>&1
if errorlevel 1 del /q "%~dp0qianmeng.bat.new" >nul 2>&1
if errorlevel 1 exit /b 0
findstr /c:"QIANMENG_INSTALLER_VERSION" "%~dp0qianmeng.bat.new" >nul 2>&1
if errorlevel 1 del /q "%~dp0qianmeng.bat.new" >nul 2>&1
if errorlevel 1 exit /b 0
move /y "%~dp0qianmeng.bat.new" "%~dp0qianmeng.bat" >nul 2>&1
if errorlevel 1 exit /b 0
call "%~dp0qianmeng.bat"
set "PENDING_UPDATE_APPLIED=1"
exit /b 0

:prompt_update
if not exist "%STATE_DIR%\latest_tag" exit /b 0
set /p "LATEST_TAG=" < "%STATE_DIR%\latest_tag"
if not defined LATEST_TAG exit /b 0
set "SEEN_TAG="
if exist "%STATE_DIR%\seen_tag" set /p "SEEN_TAG=" < "%STATE_DIR%\seen_tag"
if "%LATEST_TAG%"=="%SEEN_TAG%" exit /b 0
powershell -NoProfile -Command "try { if(([version]('%LATEST_TAG%'.TrimStart('v'))) -gt ([version]('%QIANMENG_INSTALLER_VERSION%'))) { exit 0 }; exit 1 } catch { exit 1 }"
if errorlevel 1 exit /b 0
echo 发现新版本：%LATEST_TAG%（当前：v%QIANMENG_INSTALLER_VERSION%）
choice /c YN /n /t 5 /d N /m "现在下载更新，并在下次启动时生效？ [Y/N]"
if errorlevel 2 goto mark_update_seen
curl.exe -fsSL -m 30 -o "%~dp0qianmeng.bat.new" "https://raw.githubusercontent.com/%REPO%/%LATEST_TAG%/qianmeng.bat"
if errorlevel 1 echo 更新下载失败，继续使用当前版本。
if errorlevel 1 del /q "%~dp0qianmeng.bat.new" >nul 2>&1
if not errorlevel 1 echo 更新已下载，下次启动时生效。
exit /b 0

:mark_update_seen
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
> "%STATE_DIR%\seen_tag" echo %LATEST_TAG%
exit /b 0

:ensure_product_setup
call :ensure_plugin dsh-client-ui-brand
if errorlevel 1 exit /b 1
call :ensure_plugin dsh-web-desktop
if errorlevel 1 exit /b 1
call :configure_brand
exit /b %ERRORLEVEL%

:ensure_plugin
set "PRODUCT_PLUGIN=%~1"
set "PRODUCT_PROFILE=%USERPROFILE%\.dsh\profiles\web"
if defined DSH_HOME set "PRODUCT_PROFILE=%DSH_HOME%\profiles\web"
if exist "%PRODUCT_PROFILE%\package.json" findstr /c:%PRODUCT_PLUGIN% "%PRODUCT_PROFILE%\package.json" >nul 2>&1
if not errorlevel 1 exit /b 0
echo 正在安装：%PRODUCT_PLUGIN%
call "%DSH_CMD%" plugin --profile web add "%PRODUCT_PLUGIN%"
exit /b %ERRORLEVEL%

:configure_brand
set "PRODUCT_PROFILE=%USERPROFILE%\.dsh\profiles\web"
if defined DSH_HOME set "PRODUCT_PROFILE=%DSH_HOME%\profiles\web"
if not exist "%PRODUCT_PROFILE%" mkdir "%PRODUCT_PROFILE%" >nul 2>&1
set "PRODUCT_PATCH=%PRODUCT_PROFILE%\cordis.patch.yml"
if not exist "%PRODUCT_PATCH%" type nul > "%PRODUCT_PATCH%"
findstr /c:"# qianmeng-installer managed brand configuration" "%PRODUCT_PATCH%" >nul 2>&1
if not errorlevel 1 exit /b 0
>> "%PRODUCT_PATCH%" echo.
>> "%PRODUCT_PATCH%" echo # qianmeng-installer managed brand configuration
>> "%PRODUCT_PATCH%" echo - id: dsh-client-ui-brand
>> "%PRODUCT_PATCH%" echo   config:
>> "%PRODUCT_PATCH%" echo     productName: 千梦
>> "%PRODUCT_PATCH%" echo     logoUrl: %LOGO_URL%
>> "%PRODUCT_PATCH%" echo     logoAlt: 千梦 logo
exit /b 0

:choose_mode
echo 千梦组件已就绪。
echo.
echo 请选择使用方式：
echo   [1] 浏览器 Web（默认）
echo   [2] 千梦客户端
choice /c 12 /n /t 10 /d 1 /m "输入编号 [1]"
if errorlevel 2 goto launch_desktop
goto launch_web

:launch_desktop
if exist "%STATE_DIR%\desktop_first_use" goto launch_desktop_now
echo.
echo 首次启动客户端可能需要下载 Electron，请耐心等待；后续启动不会重复下载。
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
type nul > "%STATE_DIR%\desktop_first_use"
:launch_desktop_now
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
echo ==== %date% %time% desktop launch ====>> "%LOG_FILE%"
call "%DSH_CMD%" plugin --profile web exec dsh-web-desktop -- --port 0 2>> "%LOG_FILE%"
if errorlevel 1 echo 启动失败，日志：%LOG_FILE%
if errorlevel 1 pause >nul
exit /b 0

:launch_web
set "WEB_PORT=3080"
if defined DSH_WEB_PORT set "WEB_PORT=%DSH_WEB_PORT%"
for /f %%p in ('powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort %WEB_PORT% -State Listen -ErrorAction SilentlyContinue ^| Select-Object -ExpandProperty OwningProcess -First 1"') do set "BUSY_PID=%%p"
if defined BUSY_PID goto port_busy
goto launch_web_now

:port_busy
echo 端口已被占用：127.0.0.1:%WEB_PORT%
echo   [1] 结束旧进程并重启（默认）
echo   [2] 直接打开已运行的页面
echo   [3] 返回
choice /c 123 /n /t 10 /d 1 /m "输入编号 [1]"
if errorlevel 3 exit /b 0
if errorlevel 2 start "" "http://127.0.0.1:%WEB_PORT%"
if errorlevel 2 exit /b 0
taskkill /PID %BUSY_PID% /F >nul 2>&1
timeout /t 2 /nobreak >nul

:launch_web_now
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
echo ==== %date% %time% web launch ====>> "%LOG_FILE%"
call "%DSH_CMD%" web 2>> "%LOG_FILE%"
if errorlevel 1 echo 启动失败，日志：%LOG_FILE%
if errorlevel 1 pause >nul
exit /b 0

:node_version_ok
set "NODE_MAJOR="
set "NODE_MINOR=0"
for /f "tokens=1,2 delims=." %%m in ("%NVER%") do (
  set "NODE_MAJOR=%%m"
  set "NODE_MINOR=%%n"
)
if not defined NODE_MAJOR exit /b 1
if %NODE_MAJOR% GEQ 24 exit /b 0
if %NODE_MAJOR% EQU 22 if %NODE_MINOR% GEQ 19 exit /b 0
exit /b 1

:find_dsh
set "DSH_CMD="
for /f "delims=" %%d in ('where dsh.cmd 2^>nul') do if not defined DSH_CMD set "DSH_CMD=%%d"
if not defined DSH_CMD exit /b 1
call "%DSH_CMD%" --version >nul 2>nul
exit /b %ERRORLEVEL%

:fail
echo 安装或配置失败，请查看上面的输出。
pause >nul
exit /b 1
