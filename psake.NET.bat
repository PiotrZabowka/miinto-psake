@ECHO OFF

SET BATCH_FILE_PATH=%~dp0
SET DEFAULT_PSAKE_NET_BASE_DIR=%BATCH_FILE_PATH:~0,-1%\..
SET PSAKE_TASKS=%*
powershell -NoProfile -ExecutionPolicy Unrestricted .\psake.NET.ps1