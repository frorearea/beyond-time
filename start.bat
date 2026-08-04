@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo  ========================================
echo    时间之外 · Beyond Time - 开发模式
echo  ========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    set "FLUTTER_BIN=..\tools\flutter\bin"
    if exist "%FLUTTER_BIN%\flutter.bat" (
        set "PATH=%CD%\%FLUTTER_BIN%;%PATH%"
    ) else (
        echo  [!] 未找到 Flutter SDK。
        echo      请将 flutter 加入 PATH，或安装到 ..\tools\flutter
        pause
        exit /b 1
    )
)

if not exist "build\web\index.html" (
    echo  [1/2] 构建 Web 版本（首次或代码有改动时）...
    call flutter build web
    if errorlevel 1 (
        echo.
        echo  构建失败。请检查 Flutter SDK。
        pause
        exit /b 1
    )
)

echo  [2/2] 启动本地服务器...
echo.
echo  服务器启动后会自动打开浏览器...
echo  关闭此窗口即可停止服务。
echo.

start "" http://localhost:4173
node server.js
pause
