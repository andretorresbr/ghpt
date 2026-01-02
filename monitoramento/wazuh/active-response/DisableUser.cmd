@echo off
:: Este arquivo chama o PowerShell repassando a entrada (JSON)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0DisableUser.ps1"
