@echo off
chcp 65001 >nul
cd /d "%~dp0"
set LOG=resultado_testes.txt
echo ==== Teste da API - %date% %time% ==== > %LOG%

rem --- Localiza o Python de verdade (ignora o atalho da Microsoft Store) ---
set "PY="
for %%V in (313 314 315 312 311 310) do (
  if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
  if not defined PY if exist "%ProgramFiles%\Python%%V\python.exe" set "PY=%ProgramFiles%\Python%%V\python.exe"
)
if not defined PY (
  py -3 -c "import sys" >nul 2>&1 && set "PY=py -3"
)
if not defined PY (
  python -c "import sys" >nul 2>&1 && set "PY=python"
)
if not defined PY (
  echo ERRO: Python nao encontrado. Instale pelo python.org. >> %LOG%
  type %LOG%
  pause
  exit /b 1
)
echo Python usado: %PY% >> %LOG%
"%PY%" --version >> %LOG% 2>&1 || %PY% --version >> %LOG% 2>&1

rem --- Ambiente virtual (recria se estiver incompleto) ---
if exist .venv if not exist .venv\Scripts\python.exe rmdir /s /q .venv
if not exist .venv\Scripts\python.exe (
  echo [1/4] Criando ambiente Python...
  if "%PY%"=="py -3" (py -3 -m venv .venv >> %LOG% 2>&1) else if "%PY%"=="python" (python -m venv .venv >> %LOG% 2>&1) else ("%PY%" -m venv .venv >> %LOG% 2>&1)
)
if not exist .venv\Scripts\python.exe (
  echo ERRO ao criar o ambiente Python. >> %LOG%
  type %LOG%
  pause
  exit /b 1
)

echo [2/4] Instalando dependencias (pode levar 1 ou 2 minutos)...
.venv\Scripts\python -m pip install -q --disable-pip-version-check -r requirements.txt -r requirements-dev.txt >> %LOG% 2>&1
if errorlevel 1 (
  echo ERRO ao instalar dependencias. >> %LOG%
  type %LOG%
  pause
  exit /b 1
)

echo [3/4] Preparando bancos de dados...
.venv\Scripts\python preparar_bancos.py
if errorlevel 1 (
  echo ERRO ao preparar o banco. Veja a mensagem acima. >> %LOG%
  pause
  exit /b 1
)
echo Bancos preparados. >> %LOG%

echo [4/4] Rodando testes...
.venv\Scripts\python -m pytest -v -p no:cacheprovider >> %LOG% 2>&1
if errorlevel 1 (
  echo RESULTADO: FALHOU >> %LOG%
  type %LOG%
  pause
  exit /b 1
)
echo RESULTADO: TODOS OS TESTES PASSARAM >> %LOG%
type %LOG%

echo.
echo Iniciando a API em http://localhost:8000/docs ...
start "API de Cadastros" cmd /k "%~dp0iniciar_api.bat"
timeout /t 4 >nul
start "" http://localhost:8000/docs
echo Pode fechar esta janela. A API continua rodando na janela "API de Cadastros".
pause
