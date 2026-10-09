@echo off
cd /d "%~dp0"
set "PY=C:\Users\Administrator\AppData\Local\Python\pythoncore-3.14-64\python.exe"
if not exist "%PY%" set "PY="
if not defined PY (
  where python >nul 2>nul && set "PY=python"
)
if not defined PY (
  where py >nul 2>nul && set "PY=py"
)
if not defined PY (
  echo [Error] Python 3 not found. Please install Python first:
  echo     https://www.python.org/downloads/
  pause
  exit /b 1
)
"%PY%" "%~dp0manage_dict.py"
pause
