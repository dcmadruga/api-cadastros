@echo off
chcp 65001 >nul
cd /d "%~dp0"
title API de Cadastros
echo API rodando em http://localhost:8000  (documentacao: http://localhost:8000/docs)
echo Para parar, feche esta janela.
.venv\Scripts\python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
