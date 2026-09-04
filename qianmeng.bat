@echo off
setlocal EnableExtensions
chcp 936 >nul

set "QIANMENG_INSTALLER_VERSION=0.1.5"
set "STATE_DIR=%USERPROFILE%\.qianmeng-installer"
set "LOG_FILE=%STATE_DIR%\qianmeng.log"
set "LOGO_URL=https://sales.ws.126.net/minisite/2026/0901/1788255726_logo.png"
set "REPO=ningbonb/qianmeng-installer"
set "BRAND_PLUGIN_NAME=dsh-client-ui-brand"
set "BRAND_PLUGIN_SPEC=dsh-client-ui-brand@0.1.10"
set "DESKTOP_PLUGIN_NAME=dsh-web-desktop"
set "DESKTOP_PLUGIN_SPEC=dsh-web-desktop@0.1.2"

set "PENDING_UPDATE_APPLIED="
if exist "%~dp0qianmeng.bat.new" call :apply_pending_update
if defined PENDING_UPDATE_APPLIED exit /b 0
start "" /b cmd /c powershell -NoProfile -WindowStyle Hidden -Command "$ErrorActionPreference='SilentlyContinue'; $tag=(Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/releases/latest' -Headers @{ 'User-Agent'='qianmeng-installer' } -TimeoutSec 5).tag_name; if($tag){ New-Item -ItemType Directory -Force -Path '%STATE_DIR%' ^| Out-Null; Set-Content -NoNewline -Encoding ascii -Path '%STATE_DIR%\latest_tag' -Value $tag }"

if exist "%APPDATA%\npm" set "PATH=%APPDATA%\npm;%PATH%"
call :find_dsh
if errorlevel 1 goto install
start "" /b cmd /c powershell -NoProfile -WindowStyle Hidden -Command "$ErrorActionPreference='SilentlyContinue'; $version=(npm view @deepseek-ai/dsh version --silent).Trim(); if($version){ New-Item -ItemType Directory -Force -Path '%STATE_DIR%' ^| Out-Null; Set-Content -NoNewline -Encoding ascii -Path '%STATE_DIR%\dsh_latest_version' -Value $version }"
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

:check_installer_update
set "INSTALLER_UPDATE_TAG="
set "INSTALLER_UPDATE_VERSION="
if not exist "%STATE_DIR%\latest_tag" exit /b 0
set /p "LATEST_TAG=" < "%STATE_DIR%\latest_tag"
if not defined LATEST_TAG exit /b 0
set "LATEST_VERSION=%LATEST_TAG%"
call :normalize_version "%LATEST_VERSION%"
set "LATEST_VERSION=%NORMALIZED_VERSION%"
if not defined LATEST_VERSION exit /b 0
call :version_is_newer "%LATEST_VERSION%" "%QIANMENG_INSTALLER_VERSION%"
if errorlevel 1 exit /b 0
set "INSTALLER_UPDATE_TAG=%LATEST_TAG%"
set "INSTALLER_UPDATE_VERSION=%LATEST_VERSION%"
exit /b 0

:download_installer_update
call :check_installer_update
if not defined INSTALLER_UPDATE_TAG exit /b 0
curl.exe -fsSL -m 30 -o "%~dp0qianmeng.bat.new" "https://raw.githubusercontent.com/%REPO%/%LATEST_TAG%/qianmeng.bat"
if errorlevel 1 (
  echo 千梦更新下载失败，请稍后重试。
  del /q "%~dp0qianmeng.bat.new" >nul 2>&1
  exit /b 1
)
set "UPDATE_HELPER=%STATE_DIR%\apply-qianmeng-update.cmd"
> "%UPDATE_HELPER%" echo @echo off
>> "%UPDATE_HELPER%" echo ping 127.0.0.1 -n 2 ^>nul
>> "%UPDATE_HELPER%" echo move /y "%~dp0qianmeng.bat.new" "%~dp0qianmeng.bat" ^>nul
>> "%UPDATE_HELPER%" echo call "%~dp0qianmeng.bat"
echo 千梦更新已下载，正在重新启动。
start "" /b cmd /c call "%UPDATE_HELPER%"
exit /b 2

:check_dsh_update
set "DSH_UPDATE_AVAILABLE="
if not exist "%STATE_DIR%\dsh_latest_version" exit /b 0
set /p "DSH_LATEST_VERSION=" < "%STATE_DIR%\dsh_latest_version"
if not defined DSH_LATEST_VERSION exit /b 0
call :normalize_version "%DSH_LATEST_VERSION%"
set "DSH_LATEST_VERSION=%NORMALIZED_VERSION%"
if not defined DSH_LATEST_VERSION exit /b 0
set "DSH_CURRENT_VERSION="
for /f "delims=" %%v in ('call "%DSH_CMD%" --version') do if not defined DSH_CURRENT_VERSION set "DSH_CURRENT_VERSION=%%v"
if not defined DSH_CURRENT_VERSION exit /b 0
call :normalize_version "%DSH_CURRENT_VERSION%"
set "DSH_CURRENT_VERSION=%NORMALIZED_VERSION%"
if not defined DSH_CURRENT_VERSION exit /b 0
call :version_is_newer "%DSH_LATEST_VERSION%" "%DSH_CURRENT_VERSION%"
if errorlevel 1 exit /b 0
set "DSH_UPDATE_AVAILABLE=1"
exit /b 0

:update_dsh
call :check_dsh_update
if not defined DSH_UPDATE_AVAILABLE exit /b 0
echo 正在更新 DeepSeek Harness：v%DSH_CURRENT_VERSION% 至 v%DSH_LATEST_VERSION%…
call npm install -g @deepseek-ai/dsh@latest
if errorlevel 1 exit /b 1
if exist "%APPDATA%\npm" set "PATH=%APPDATA%\npm;%PATH%"
call :find_dsh
exit /b %ERRORLEVEL%

:normalize_version
set "NORMALIZED_VERSION="
for /f "tokens=1,2 delims= v" %%a in ("%~1") do (
  set "NORMALIZED_VERSION=%%b"
  if not defined NORMALIZED_VERSION set "NORMALIZED_VERSION=%%a"
)
exit /b 0

:version_is_newer
setlocal
for /f "tokens=1 delims=-" %%a in ("%~1") do set "CANDIDATE_CORE=%%a"
for /f "tokens=1 delims=-" %%a in ("%~2") do set "CURRENT_CORE=%%a"
powershell -NoProfile -Command "try { if(([version]'%CANDIDATE_CORE%') -gt ([version]'%CURRENT_CORE%')) { exit 0 }; exit 1 } catch { exit 1 }"
set "RESULT=%ERRORLEVEL%"
endlocal & exit /b %RESULT%

:ensure_product_setup
set "RECONCILE_COMPONENTS=0"
set "COMPONENTS_RELEASE=%BRAND_PLUGIN_SPEC%|%DESKTOP_PLUGIN_SPEC%"
set "COMPONENTS_VERSION="
if exist "%STATE_DIR%\components_version" set /p "COMPONENTS_VERSION=" < "%STATE_DIR%\components_version"
if not "%COMPONENTS_VERSION%"=="%COMPONENTS_RELEASE%" set "RECONCILE_COMPONENTS=1"
call :ensure_plugin "%BRAND_PLUGIN_NAME%" "%BRAND_PLUGIN_SPEC%"
if errorlevel 1 exit /b 1
call :ensure_plugin "%DESKTOP_PLUGIN_NAME%" "%DESKTOP_PLUGIN_SPEC%"
if errorlevel 1 exit /b 1
call :configure_brand
if errorlevel 1 exit /b 1
if not "%RECONCILE_COMPONENTS%"=="1" exit /b 0
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
> "%STATE_DIR%\components_version" echo %COMPONENTS_RELEASE%
exit /b 0

:ensure_plugin
set "PRODUCT_PLUGIN=%~1"
set "PRODUCT_PLUGIN_SPEC=%~2"
set "PRODUCT_PROFILE=%USERPROFILE%\.dsh\profiles\web"
if defined DSH_HOME set "PRODUCT_PROFILE=%DSH_HOME%\profiles\web"
if "%RECONCILE_COMPONENTS%"=="1" goto install_product_plugin
if exist "%PRODUCT_PROFILE%\package.json" findstr /c:%PRODUCT_PLUGIN% "%PRODUCT_PROFILE%\package.json" >nul 2>&1
if not errorlevel 1 exit /b 0
:install_product_plugin
echo 正在安装或更新：%PRODUCT_PLUGIN_SPEC%
call "%DSH_CMD%" plugin --profile web add "%PRODUCT_PLUGIN_SPEC%"
exit /b %ERRORLEVEL%

:configure_brand
set "PRODUCT_PROFILE=%USERPROFILE%\.dsh\profiles\web"
if defined DSH_HOME set "PRODUCT_PROFILE=%DSH_HOME%\profiles\web"
if not exist "%PRODUCT_PROFILE%" mkdir "%PRODUCT_PROFILE%" >nul 2>&1
set "PRODUCT_PATCH=%PRODUCT_PROFILE%\cordis.patch.yml"
if not exist "%PRODUCT_PATCH%" type nul > "%PRODUCT_PATCH%"
set "PATCH_FIRST_LINE="
set /p "PATCH_FIRST_LINE=" < "%PRODUCT_PATCH%"
if not "%PATCH_FIRST_LINE%"=="[]" goto brand_patch_normalized
more +1 "%PRODUCT_PATCH%" > "%PRODUCT_PATCH%.new"
move /y "%PRODUCT_PATCH%.new" "%PRODUCT_PATCH%" >nul 2>&1
:brand_patch_normalized
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
call :check_dsh_update
call :check_installer_update
set "DSH_UPDATE_OPTION="
set "INSTALLER_UPDATE_OPTION="
set "NEXT_UPDATE_OPTION=3"
if defined DSH_UPDATE_AVAILABLE set "DSH_UPDATE_OPTION=%NEXT_UPDATE_OPTION%"
if defined DSH_UPDATE_AVAILABLE set "NEXT_UPDATE_OPTION=4"
if defined INSTALLER_UPDATE_TAG set "INSTALLER_UPDATE_OPTION=%NEXT_UPDATE_OPTION%"
echo.
echo 千梦已准备好，请选择操作：
echo   [1] 通过浏览器打开
echo   [2] 通过客户端打开
if defined DSH_UPDATE_AVAILABLE echo   [%DSH_UPDATE_OPTION%] 更新 DeepSeek Harness（v%DSH_CURRENT_VERSION% 至 v%DSH_LATEST_VERSION%）
if defined INSTALLER_UPDATE_TAG echo   [%INSTALLER_UPDATE_OPTION%] 更新千梦（v%QIANMENG_INSTALLER_VERSION% 至 v%INSTALLER_UPDATE_VERSION%）
set "MODE_CHOICE="
set /p "MODE_CHOICE=输入编号："
if not defined MODE_CHOICE goto launch_web
if "%MODE_CHOICE%"=="1" goto launch_web
if "%MODE_CHOICE%"=="2" goto launch_desktop
if "%MODE_CHOICE%"=="%DSH_UPDATE_OPTION%" if defined DSH_UPDATE_AVAILABLE goto update_dsh_from_menu
if "%MODE_CHOICE%"=="%INSTALLER_UPDATE_OPTION%" if defined INSTALLER_UPDATE_TAG goto download_installer_update_from_menu
echo 输入无效，请重新选择。
goto choose_mode

:update_dsh_from_menu
call :update_dsh
if errorlevel 1 goto fail
goto choose_mode

:download_installer_update_from_menu
call :download_installer_update
if errorlevel 2 exit /b 0
goto choose_mode

:launch_desktop
if exist "%STATE_DIR%\desktop_first_use" goto launch_desktop_now
echo.
echo 首次启动客户端可能需要下载 Electron，请耐心等待；后续启动不会重复下载。
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
type nul > "%STATE_DIR%\desktop_first_use"
:launch_desktop_now
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
call :ensure_dsh_shim
if errorlevel 1 goto fail
echo ==== %date% %time% desktop launch ====>> "%LOG_FILE%"
call "%DSH_CMD%" plugin --profile web exec dsh-web-desktop -- --port 0 2>> "%LOG_FILE%"
if errorlevel 1 echo 启动失败，日志：%LOG_FILE%
if errorlevel 1 pause >nul
exit /b 0

:ensure_dsh_shim
rem 客户端插件用 Node spawn(无shell) 直接调用名为 dsh 的程序，在 Windows/Node22 下
rem 会因扩展名解析失败(ENOENT)或拒绝执行 .cmd(EINVAL)。此处编译一个原生 exe 转发器，
rem 通过 DSH_BIN 指定，使 spawn 能稳定拉起 node bin.js。
set "DSH_SHIM_EXE=%STATE_DIR%\dsh-shim.exe"
rem 定位 node.exe
set "DSH_SHIM_NODE="
for /f "delims=" %%n in ('where node 2^>nul') do if not defined DSH_SHIM_NODE set "DSH_SHIM_NODE=%%n"
if not defined DSH_SHIM_NODE set "DSH_SHIM_NODE=node.exe"
rem 定位 dsh 的 JS 入口 bin.js（%DSH_CMD% 位于 npm 全局 bin 目录）
for %%d in ("%DSH_CMD%") do set "DSH_NPM_DIR=%%~dpd"
set "DSH_SHIM_BINJS=%DSH_NPM_DIR%node_modules\@deepseek-ai\dsh\lib\bin.js"
if not exist "%DSH_SHIM_BINJS%" set "DSH_SHIM_BINJS=%APPDATA%\npm\node_modules\@deepseek-ai\dsh\lib\bin.js"
rem 已编译则直接用
if exist "%DSH_SHIM_EXE%" goto shim_ready
rem 用系统自带 csc 编译 shim
set "DSH_SHIM_CSC="
if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "DSH_SHIM_CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined DSH_SHIM_CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "DSH_SHIM_CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined DSH_SHIM_CSC for /f "delims=" %%c in ('dir /b /s "%WINDIR%\Microsoft.NET\Framework64\csc.exe" 2^>nul') do if not defined DSH_SHIM_CSC set "DSH_SHIM_CSC=%%c"
if not defined DSH_SHIM_CSC for /f "delims=" %%c in ('dir /b /s "%WINDIR%\Microsoft.NET\Framework\csc.exe" 2^>nul') do if not defined DSH_SHIM_CSC set "DSH_SHIM_CSC=%%c"
if not defined DSH_SHIM_CSC echo 无法找到 C# 编译器，客户端模式不可用，请改用浏览器 Web 模式。& exit /b 1
set "DSH_SHIM_CS=%STATE_DIR%\dsh-shim.cs"
> "%DSH_SHIM_CS%" echo using System;
>> "%DSH_SHIM_CS%" echo using System.Diagnostics;
>> "%DSH_SHIM_CS%" echo using System.Text;
>> "%DSH_SHIM_CS%" echo class DshShim {
>> "%DSH_SHIM_CS%" echo   static int Main(string[] args) {
>> "%DSH_SHIM_CS%" echo     string node = Environment.GetEnvironmentVariable("DSH_SHIM_NODE");
>> "%DSH_SHIM_CS%" echo     string binjs = Environment.GetEnvironmentVariable("DSH_SHIM_BINJS");
>> "%DSH_SHIM_CS%" echo     var sb = new StringBuilder();
>> "%DSH_SHIM_CS%" echo     sb.Append('"').Append(binjs).Append('"');
>> "%DSH_SHIM_CS%" echo     foreach (var a in args) {
>> "%DSH_SHIM_CS%" echo       sb.Append(' ');
>> "%DSH_SHIM_CS%" echo       if (a.Length == 0) { sb.Append("\"\""); continue; }
>> "%DSH_SHIM_CS%" echo       if (a.IndexOfAny(new char[]{' ','\t','"'}) == -1) { sb.Append(a); }
>> "%DSH_SHIM_CS%" echo       else { sb.Append('"'); sb.Append(a.Replace("\\", "\\\\").Replace("\"", "\\\"")); sb.Append('"'); }
>> "%DSH_SHIM_CS%" echo     }
>> "%DSH_SHIM_CS%" echo     var psi = new ProcessStartInfo();
>> "%DSH_SHIM_CS%" echo     psi.FileName = node; psi.Arguments = sb.ToString(); psi.UseShellExecute = false;
>> "%DSH_SHIM_CS%" echo     var p = Process.Start(psi); p.WaitForExit(); return p.ExitCode;
>> "%DSH_SHIM_CS%" echo   }
>> "%DSH_SHIM_CS%" echo }
"%DSH_SHIM_CSC%" /nologo /optimize /target:exe /out:"%DSH_SHIM_EXE%" "%DSH_SHIM_CS%" >nul 2>&1
if not exist "%DSH_SHIM_EXE%" echo 客户端启动器编译失败，请改用浏览器 Web 模式。& exit /b 1
:shim_ready
set "DSH_BIN=%DSH_SHIM_EXE%"
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
