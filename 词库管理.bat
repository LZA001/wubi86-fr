@echo off
chcp 65001 >nul
cd /d "%~dp0"
set PY=
if exist "C:\Users\Administrator\AppData\Local\Python\pythoncore-3.14-64\python.exe" set PY=C:\Users\Administrator\AppData\Local\Python\pythoncore-3.14-64\python.exe
if not defined PY where python >nul 2>nul && set PY=python
if not defined PY where py >nul 2>nul && set PY=py
if not defined PY (
  echo 未找到 Python 3，请先安装 Python（https://www.python.org/downloads/）
  pause
  exit /b 1
)
"%PY%" "%~dp0manage_dict.py"
pause
