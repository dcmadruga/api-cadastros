#!/usr/bin/env bash
# Gera dist/Instalador-API-Cadastros-<versão>.exe
# Requisitos: python3 + pip, makensis (NSIS 3), curl. Funciona no Linux (inclusive no GitHub Actions).
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"

VERSAO=$(python3 -c "exec(open('api/app/versao.py').read()); print(VERSAO)")
WINSW_URL="https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW.NET461.exe"
WINSW_SHA256="b5066b7bbdfba1293e5d15cda3caaea88fbeab35bd5b38c41c913d492aadfc4f"
echo ">> Versão $VERSAO"

BUILD="instalador/build"
rm -rf "$BUILD" && mkdir -p "$BUILD/wheels" dist

echo ">> Copiando arquivos da API"
cp -r api/app api/migracoes "$BUILD/"
cp api/requirements.txt api/preparar_bancos.py api/servidor.pyw api/schema.sql api/.env.example "$BUILD/"
cp README.md "$BUILD/README.md"
echo "$VERSAO" > "$BUILD/VERSAO.txt"
find "$BUILD" -name __pycache__ -prune -exec rm -rf {} +

echo ">> Baixando pacotes Python para Windows (3.12, 3.13, 3.14)"
for v in 3.12 3.13 3.14; do
  python3 -m pip download -q --only-binary=:all: --platform win_amd64 --python-version "$v" \
    --implementation cp -d "$BUILD/wheels" -r api/requirements.txt tzdata colorama
done

echo ">> Baixando WinSW (gerenciador do serviço do Windows)"
mkdir -p .cache
[ -f .cache/WinSW.exe ] || curl -sSfL -o .cache/WinSW.exe "$WINSW_URL"
echo "$WINSW_SHA256  .cache/WinSW.exe" | sha256sum -c --quiet
cp .cache/WinSW.exe "$BUILD/ApiCadastros.exe"
cp instalador/ApiCadastros.xml "$BUILD/"
cp instalador/LICENCA-WinSW.txt "$BUILD/"

echo ">> Compilando o instalador"
(cd instalador && makensis -V2 -INPUTCHARSET UTF8 -DAPP_VERSAO="$VERSAO" api-cadastros.nsi)
rm -rf "$BUILD"
ls -l "dist/Instalador-API-Cadastros-$VERSAO.exe"
