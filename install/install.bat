@echo off
chcp 65001 >nul
title 安装 Trae Auto Checkin 插件

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*

echo.
pause
