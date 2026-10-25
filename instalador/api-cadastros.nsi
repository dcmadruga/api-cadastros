; Instalador da API de Cadastros (clientes, produtos e fornecedores)
; Gerado com NSIS 3. Instala a API como serviço do Windows (requer administrador).
; O serviço é gerenciado pelo WinSW 2.12 (https://github.com/winsw/winsw, licença MIT).

Unicode true
!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "WordFunc.nsh"
!include "FileFunc.nsh"

!define APP_NOME "API de Cadastros"
; a versão vem de api/app/versao.py (passada pelo scripts/build_instalador.sh)
!ifndef APP_VERSAO
  !define APP_VERSAO "0.0.0"
!endif
!define APP_ID "ApiCadastros"
!define SERVICO "$INSTDIR\ApiCadastros.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"

Name "${APP_NOME}"
OutFile "..\dist\Instalador-API-Cadastros-${APP_VERSAO}.exe"
InstallDir "$PROGRAMFILES64\${APP_ID}"
InstallDirRegKey HKLM "Software\${APP_ID}" "PastaInstalacao"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
ShowInstDetails show
BrandingText "${APP_NOME} ${APP_VERSAO}"

VIProductVersion "${APP_VERSAO}.0"
VIAddVersionKey /LANG=0 "ProductName" "${APP_NOME}"
VIAddVersionKey /LANG=0 "FileDescription" "Instalador da ${APP_NOME}"
VIAddVersionKey /LANG=0 "FileVersion" "${APP_VERSAO}"
VIAddVersionKey /LANG=0 "ProductVersion" "${APP_VERSAO}"
VIAddVersionKey /LANG=0 "LegalCopyright" ""

Var PY
Var LOG
Var DbHost
Var DbPort
Var DbUser
Var DbPass
Var DbName
Var ApiPort
Var DbSchema
Var hSchema
Var EnvChave
Var EnvValor
Var hHost
Var hPort
Var hUser
Var hPass
Var hName
Var hApiPort

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Instalação da ${APP_NOME}"
!define MUI_WELCOMEPAGE_TEXT "Este assistente vai instalar a ${APP_NOME} (clientes, produtos e fornecedores) neste computador.$\r$\n$\r$\nRequisitos:$\r$\n  • Python 3.12, 3.13 ou 3.14 instalado$\r$\n  • Acesso a um servidor PostgreSQL$\r$\n$\r$\nA API será instalada como serviço do Windows: liga sozinha com o computador, mesmo sem ninguém conectado, e reinicia automaticamente em caso de falha.$\r$\n$\r$\nNão é preciso internet: todos os componentes já estão no instalador.$\r$\n$\r$\nClique em Avançar para continuar."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom PaginaBanco PaginaBancoSair
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "Instalação concluída"
!define MUI_FINISHPAGE_TEXT "A ${APP_NOME} foi instalada como serviço do Windows e já está em execução.$\r$\n$\r$\nNo Menu Iniciar, na pasta $\"${APP_NOME}$\", estão os atalhos para abrir a documentação, reiniciar, parar e configurar a conexão. O serviço também aparece em services.msc."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Abrir a documentação da API"
!define MUI_FINISHPAGE_RUN_FUNCTION AbrirDocumentacao
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "PortugueseBR"

; ---------------------------------------------------------------- Registro (log) da instalação
; Arquivo: C:\ProgramData\ApiCadastros\instalacao.txt (cada execução é acrescentada ao final).
; A senha do banco NUNCA é gravada no registro.
!macro DefinirEscreverLog PREFIXO
Function ${PREFIXO}EscreverLog
  Exch $0
  Push $1
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6
  Push $7
  Push $8
  ${GetTime} "" "L" $1 $2 $3 $4 $5 $6 $7
  FileOpen $8 "$LOG" a
  ${IfNot} ${Errors}
    FileSeek $8 0 END
    FileWrite $8 "[$3-$2-$1 $5:$6:$7] $0$\r$\n"
    FileClose $8
  ${EndIf}
  ClearErrors
  DetailPrint "$0"
  Pop $8
  Pop $7
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Pop $0
FunctionEnd
!macroend
!insertmacro DefinirEscreverLog ""
!insertmacro DefinirEscreverLog "un."

!macro Log TEXTO
  Push `${TEXTO}`
  Call EscreverLog
!macroend
!macro unLog TEXTO
  Push `${TEXTO}`
  Call un.EscreverLog
!macroend

; Executa um comando gravando TODA a saída (e erros) no registro; código de saída em $0
!macro Rodar DESCRICAO LINHA
  !insertmacro Log "${DESCRICAO}"
  !insertmacro Log `  comando: ${LINHA}`
  nsExec::ExecToLog '"$SYSDIR\cmd.exe" /S /C "${LINHA} >> "$LOG" 2>&1"'
  Pop $0
  !insertmacro Log "  código de saída: $0"
!macroend
!macro unRodar DESCRICAO LINHA
  !insertmacro unLog "${DESCRICAO}"
  nsExec::ExecToLog '"$SYSDIR\cmd.exe" /S /C "${LINHA} >> "$LOG" 2>&1"'
  Pop $0
  !insertmacro unLog "  código de saída: $0"
!macroend

!macro IniciarLog
  CreateDirectory "$APPDATA\${APP_ID}"
  StrCpy $LOG "$APPDATA\${APP_ID}\instalacao.txt"
  FileOpen $9 "$LOG" a
  FileSeek $9 0 END
  FileWrite $9 "$\r$\n==================================================================$\r$\n"
  FileClose $9
!macroend

Function .onInstFailed
  !insertmacro Log "*** INSTALAÇÃO NÃO CONCLUÍDA (falhou ou foi cancelada) ***"
  CopyFiles /SILENT "$LOG" "$INSTDIR\logs\instalacao.txt"
  MessageBox MB_ICONSTOP "A instalação não foi concluída.$\r$\n$\r$\nO registro completo, com os erros, foi gravado em:$\r$\n$LOG$\r$\n$\r$\nEle será aberto agora. Envie esse arquivo para o suporte."
  Exec '"$WINDIR\notepad.exe" "$LOG"'
FunctionEnd

; ---------------------------------------------------------------- Leitura do .env existente
; Entrada: $EnvChave (ex.: DB_NAME). Saída: $EnvValor (vazio se não encontrado). Não lê a senha.
Function LerEnv
  Push $R2
  Push $R3
  Push $R4
  Push $R5
  StrCpy $EnvValor ""
  ClearErrors
  FileOpen $R2 "$INSTDIR\.env" r
  IfErrors lerenv_fim
  StrLen $R5 "$EnvChave="
  lerenv_loop:
    ClearErrors
    FileRead $R2 $R3
    IfErrors lerenv_fecha
    StrCpy $R4 $R3 $R5
    StrCmp $R4 "$EnvChave=" 0 lerenv_loop
    StrCpy $EnvValor $R3 "" $R5
    lerenv_trim:
      StrCpy $R4 $EnvValor 1 -1
      StrCmp $R4 "$\r" +2
      StrCmp $R4 "$\n" 0 lerenv_fecha
      StrCpy $EnvValor $EnvValor -1
      Goto lerenv_trim
  lerenv_fecha:
    FileClose $R2
  lerenv_fim:
  ClearErrors
  Pop $R5
  Pop $R4
  Pop $R3
  Pop $R2
FunctionEnd

!macro PreencherDoEnv CHAVE VAR
  StrCpy $EnvChave "${CHAVE}"
  Call LerEnv
  ${If} $EnvValor != ""
    StrCpy ${VAR} $EnvValor
  ${EndIf}
!macroend

; ---------------------------------------------------------------- Python
!macro TentarPython HIVE VER
  ${If} $PY == ""
    ReadRegStr $0 ${HIVE} "Software\Python\PythonCore\${VER}\InstallPath" "ExecutablePath"
    ${If} $0 == ""
      ReadRegStr $0 ${HIVE} "Software\Python\PythonCore\${VER}\InstallPath" ""
      ${If} $0 != ""
        StrCpy $0 "$0\python.exe"
      ${EndIf}
    ${EndIf}
    ${If} $0 != ""
    ${AndIf} ${FileExists} "$0"
      StrCpy $PY "$0"
    ${EndIf}
  ${EndIf}
!macroend

!macro TentarPasta CAMINHO
  ${If} $PY == ""
  ${AndIf} ${FileExists} "${CAMINHO}"
    StrCpy $PY "${CAMINHO}"
  ${EndIf}
!macroend

!macro OpcaoLinha OPCAO VAR
  ClearErrors
  ${GetOptions} $1 "${OPCAO}" $2
  ${IfNot} ${Errors}
  ${AndIf} $2 != ""
    StrCpy ${VAR} $2
  ${EndIf}
  ClearErrors
!macroend

Function .onInit
  SetShellVarContext all
  SetRegView 64
  !insertmacro IniciarLog
  !insertmacro Log "Instalador da ${APP_NOME} ${APP_VERSAO} iniciado"
  ReadRegStr $1 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" "ProductName"
  ReadRegStr $2 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" "DisplayVersion"
  ReadRegStr $3 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" "CurrentBuild"
  !insertmacro Log "Windows: $1 $2 (build $3)"
  ReadEnvStr $1 "USERNAME"
  ReadEnvStr $2 "COMPUTERNAME"
  !insertmacro Log "Usuário: $1   Computador: $2"
  ReadRegStr $1 HKLM "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" "Release"
  !insertmacro Log ".NET Framework 4 (Release): $1  (WinSW precisa de 394254 ou maior)"
  StrCpy $PY ""
  !insertmacro TentarPython HKCU "3.13"
  !insertmacro TentarPython HKLM "3.13"
  !insertmacro TentarPython HKCU "3.14"
  !insertmacro TentarPython HKLM "3.14"
  !insertmacro TentarPython HKCU "3.12"
  !insertmacro TentarPython HKLM "3.12"
  !insertmacro TentarPasta "$LOCALAPPDATA\Programs\Python\Python313\python.exe"
  !insertmacro TentarPasta "$LOCALAPPDATA\Programs\Python\Python314\python.exe"
  !insertmacro TentarPasta "$LOCALAPPDATA\Programs\Python\Python312\python.exe"
  !insertmacro TentarPasta "$PROGRAMFILES64\Python313\python.exe"
  !insertmacro TentarPasta "$PROGRAMFILES64\Python314\python.exe"
  !insertmacro TentarPasta "$PROGRAMFILES64\Python312\python.exe"

  ${If} $PY == ""
    !insertmacro Log "ERRO: Python 3.12, 3.13 ou 3.14 não encontrado"
    MessageBox MB_YESNO|MB_ICONEXCLAMATION "Não encontrei o Python 3.12, 3.13 ou 3.14 neste computador.$\r$\n$\r$\nA API precisa dele para funcionar. Deseja abrir o site python.org para baixá-lo?$\r$\n(Depois de instalar o Python, rode este instalador de novo.)" IDNO +2
      ExecShell "open" "https://www.python.org/downloads/windows/"
    Abort
  ${EndIf}
  !insertmacro Log "Python encontrado: $PY"

  ; valores padrão da página de conexão
  StrCpy $DbHost "localhost"
  StrCpy $DbPort "5432"
  StrCpy $DbUser "postgres"
  StrCpy $DbPass ""
  StrCpy $DbName "api_db"
  StrCpy $ApiPort "8000"
  StrCpy $DbSchema "api_cadastros"
  ${If} ${FileExists} "$INSTDIR\.env"
    !insertmacro PreencherDoEnv "DB_HOST" $DbHost
    !insertmacro PreencherDoEnv "DB_PORT" $DbPort
    !insertmacro PreencherDoEnv "DB_USER" $DbUser
    !insertmacro PreencherDoEnv "DB_NAME" $DbName
    !insertmacro PreencherDoEnv "DB_SCHEMA" $DbSchema
    !insertmacro PreencherDoEnv "API_PORT" $ApiPort
    !insertmacro Log "Configuração anterior encontrada: servidor=$DbHost porta=$DbPort banco=$DbName schema=$DbSchema portaAPI=$ApiPort"
  ${EndIf}

  ; opções de linha de comando têm prioridade sobre o .env
  ; ex.: Instalador.exe /BANCO=base_teste /SCHEMA=api_cadastros /SERVIDOR=localhost /PORTA=5432
  ${GetParameters} $1
  ${If} $1 != ""
    !insertmacro Log "Opções recebidas: $1"
    !insertmacro OpcaoLinha "/SERVIDOR=" $DbHost
    !insertmacro OpcaoLinha "/PORTA=" $DbPort
    !insertmacro OpcaoLinha "/USUARIO=" $DbUser
    !insertmacro OpcaoLinha "/BANCO=" $DbName
    !insertmacro OpcaoLinha "/SCHEMA=" $DbSchema
    !insertmacro OpcaoLinha "/PORTAAPI=" $ApiPort
  ${EndIf}
FunctionEnd

; ---------------------------------------------------------------- Página do banco
Function PaginaBanco
  !insertmacro MUI_HEADER_TEXT "Conexão com o PostgreSQL" "Informe onde está o banco de dados que a API vai usar."
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 20u "O banco é criado se não existir. Documentação da API: http://localhost:<porta da API>/docs"
  Pop $0

  ${NSD_CreateLabel} 0 24u 30% 12u "Servidor:"
  Pop $0
  ${NSD_CreateText} 32% 22u 45% 12u "$DbHost"
  Pop $hHost
  ${NSD_CreateLabel} 0 40u 30% 12u "Porta:"
  Pop $0
  ${NSD_CreateNumber} 32% 38u 20% 12u "$DbPort"
  Pop $hPort
  ${NSD_CreateLabel} 0 56u 30% 12u "Usuário:"
  Pop $0
  ${NSD_CreateText} 32% 54u 45% 12u "$DbUser"
  Pop $hUser
  ${NSD_CreateLabel} 0 72u 30% 12u "Senha:"
  Pop $0
  ${NSD_CreatePassword} 32% 70u 45% 12u "$DbPass"
  Pop $hPass
  ${NSD_CreateLabel} 0 88u 30% 12u "Nome do banco:"
  Pop $0
  ${NSD_CreateText} 32% 86u 45% 12u "$DbName"
  Pop $hName
  ${NSD_CreateLabel} 0 104u 30% 12u "Schema da API:"
  Pop $0
  ${NSD_CreateText} 32% 102u 45% 12u "$DbSchema"
  Pop $hSchema
  ${NSD_CreateLabel} 0 120u 30% 12u "Porta da API:"
  Pop $0
  ${NSD_CreateNumber} 32% 118u 20% 12u "$ApiPort"
  Pop $hApiPort
  ${NSD_CreateLabel} 0 134u 100% 12u "As tabelas da API ficam só no schema acima; outras tabelas do banco não são alteradas."
  Pop $0

  ${NSD_SetFocus} $hPass
  nsDialogs::Show
FunctionEnd

Function PaginaBancoSair
  ${NSD_GetText} $hHost $DbHost
  ${NSD_GetText} $hPort $DbPort
  ${NSD_GetText} $hUser $DbUser
  ${NSD_GetText} $hPass $DbPass
  ${NSD_GetText} $hName $DbName
  ${NSD_GetText} $hSchema $DbSchema
  ${NSD_GetText} $hApiPort $ApiPort
  ${If} $DbHost == ""
  ${OrIf} $DbPort == ""
  ${OrIf} $DbUser == ""
  ${OrIf} $DbName == ""
  ${OrIf} $DbSchema == ""
  ${OrIf} $ApiPort == ""
    MessageBox MB_ICONEXCLAMATION "Preencha servidor, porta, usuário, nome do banco, schema e porta da API."
    Abort
  ${EndIf}
  ${If} $DbPass == ""
    MessageBox MB_YESNO|MB_ICONQUESTION "A senha está em branco. Continuar mesmo assim?" IDYES +2
    Abort
  ${EndIf}
  ; confirmação explícita do banco, para não seguir com o valor preenchido sem perceber
  StrCpy $0 ""
  MessageBox MB_YESNO|MB_ICONQUESTION "A API vai usar:$\r$\n$\r$\n    Banco:  $DbName$\r$\n    Schema:  $DbSchema$\r$\n    Servidor:  $DbHost:$DbPort$\r$\n$\r$\nEstá certo? (Não = voltar e corrigir)" IDYES +2
    StrCpy $0 "corrigir"
  ${If} $0 == "corrigir"
    !insertmacro Log "Usuário pediu para corrigir a conexão (banco=$DbName)"
    Abort
  ${EndIf}
  StrLen $1 $DbPass
  !insertmacro Log "Conexão escolhida: servidor=$DbHost porta=$DbPort usuário=$DbUser banco=$DbName schema=$DbSchema portaAPI=$ApiPort senha=($1 caracteres, não registrada)"
FunctionEnd

; ---------------------------------------------------------------- Instalação
; Executa um comando do serviço (install, start, stop, uninstall...) e devolve o código em $0
!macro Servico ACAO
  !insertmacro Rodar "Serviço: ${ACAO}" '"${SERVICO}" ${ACAO}'
!macroend
!macro unServico ACAO
  !insertmacro unRodar "Serviço: ${ACAO}" '"${SERVICO}" ${ACAO}'
!macroend

; Atalho que pede permissão de administrador (UAC) para executar um programa
!macro AtalhoAdmin ARQUIVO PROGRAMA ARGS
  CreateShortCut "${ARQUIVO}" "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" "-NoProfile -WindowStyle Hidden -Command $\"Start-Process -FilePath '${PROGRAMA}' -ArgumentList '${ARGS}' -Verb RunAs -WindowStyle Hidden$\"" "${PROGRAMA}" 0 SW_SHOWMINIMIZED
!macroend

Section "API de Cadastros como serviço (obrigatório)" SecApp
  SectionIn RO
  SetShellVarContext all
  SetRegView 64

  ; Atualização: para e remove o serviço antigo antes de substituir os arquivos
  !insertmacro Log "Pasta de instalação: $INSTDIR"
  ${If} ${FileExists} "${SERVICO}"
    !insertmacro Log "Versão anterior encontrada: parando o serviço"
    !insertmacro Servico "stop"
    Sleep 2000
    !insertmacro Servico "uninstall"
    Sleep 1000
  ${EndIf}

  !insertmacro Log "Copiando arquivos da API..."
  SetOutPath "$INSTDIR"
  File /r "build\app"
  File /r "build\migracoes"
  File "build\requirements.txt"
  File "build\preparar_bancos.py"
  File "build\servidor.pyw"
  File "build\VERSAO.txt"
  File "build\schema.sql"
  File "build\README.md"
  File "build\.env.example"
  File "build\ApiCadastros.exe"
  File "build\ApiCadastros.xml"
  File "build\LICENCA-WinSW.txt"
  SetOutPath "$INSTDIR\wheels"
  File "build\wheels\*.whl"
  SetOutPath "$INSTDIR"
  CreateDirectory "$INSTDIR\logs"
  !insertmacro Log "Arquivos copiados"

  ; ---- arquivo de configuração (.env) ----
  ; senha entre aspas simples; escapa \ e ' no formato do python-dotenv
  ${WordReplace} "$DbPass" "\" "\\" "+" $1
  ${WordReplace} "$1" "'" "\'" "+" $1
  !insertmacro Log "Gravando configuração (.env)..."
  FileOpen $9 "$INSTDIR\.env" w
  FileWrite $9 "# Configuracao da API de Cadastros (gerada pelo instalador)$\r$\n"
  FileWrite $9 "# Depois de alterar, use o atalho Reiniciar API no Menu Iniciar.$\r$\n"
  FileWrite $9 "DB_HOST=$DbHost$\r$\n"
  FileWrite $9 "DB_PORT=$DbPort$\r$\n"
  FileWrite $9 "DB_USER=$DbUser$\r$\n"
  FileWrite $9 "DB_PASSWORD='$1'$\r$\n"
  FileWrite $9 "DB_NAME=$DbName$\r$\n"
  FileWrite $9 "DB_SCHEMA=$DbSchema$\r$\n"
  FileWrite $9 "DB_TEST_NAME=api_test$\r$\n"
  FileWrite $9 "API_HOST=127.0.0.1$\r$\n"
  FileWrite $9 "API_PORT=$ApiPort$\r$\n"
  FileClose $9
  ; a senha fica legível só para administradores e para o serviço (SYSTEM)
  !insertmacro Rodar "Protegendo o arquivo .env (só administradores e o serviço)" 'icacls "$INSTDIR\.env" /inheritance:r /grant:r *S-1-5-32-544:F *S-1-5-18:F'
  ${If} $0 != 0
    !insertmacro Log "AVISO: não foi possível proteger o .env (código $0); a instalação continua"
  ${EndIf}

  ; ---- ambiente Python ----
  ${IfNot} ${FileExists} "$INSTDIR\.venv\Scripts\python.exe"
    !insertmacro Rodar "Versão do Python" '"$PY" --version'
    !insertmacro Rodar "Criando ambiente Python" '"$PY" -m venv "$INSTDIR\.venv"'
    ${If} $0 != 0
      !insertmacro Log "ERRO: falha ao criar o ambiente Python"
      MessageBox MB_ICONSTOP "Não foi possível criar o ambiente Python (código $0)."
      Abort
    ${EndIf}
  ${EndIf}

  !insertmacro Rodar "Instalando componentes (sem internet)" '"$INSTDIR\.venv\Scripts\python.exe" -m pip install --no-index --find-links "$INSTDIR\wheels" --disable-pip-version-check -r "$INSTDIR\requirements.txt"'
  ${If} $0 != 0
    !insertmacro Log "ERRO: falha ao instalar os componentes"
    MessageBox MB_ICONSTOP "Falha ao instalar os componentes da API (código $0). Veja os detalhes nesta janela."
    Abort
  ${EndIf}

  ; ---- banco de dados ----
  StrCpy $8 "ok"
  !insertmacro Rodar "Conectando ao PostgreSQL e preparando o banco $DbName, schema $DbSchema (tabelas e migrações)" '"$INSTDIR\.venv\Scripts\python.exe" "$INSTDIR\preparar_bancos.py" --instalador'
  ${If} $0 != 0
    !insertmacro Log "AVISO: o banco não foi preparado (código $0); a API foi instalada mesmo assim"
  ${EndIf}
  ${If} $0 == 2
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "A API foi instalada, mas o PostgreSQL recusou o usuário ou a senha.$\r$\n$\r$\nUse o atalho $\"Configurar conexão$\" no Menu Iniciar para corrigir e depois $\"Reiniciar API$\"."
  ${ElseIf} $0 == 4
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "O banco $DbName já tem, no schema $DbSchema, tabelas clientes/produtos/fornecedores de OUTRO sistema.$\r$\n$\r$\nNada foi alterado. Rode o instalador de novo e use outro schema (recomendado: api_cadastros) ou outro banco."
  ${ElseIf} $0 == 3
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "A API foi instalada, mas não encontrei o PostgreSQL em $DbHost:$DbPort.$\r$\n$\r$\nConfira se o servidor está ligado e use o atalho $\"Configurar conexão$\" para ajustar."
  ${ElseIf} $0 != 0
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "A API foi instalada, mas houve um erro ao preparar o banco (código $0). Veja os detalhes nesta janela."
  ${EndIf}

  ; ---- serviço do Windows ----
  !insertmacro Servico "install"
  ${If} $0 != 0
    !insertmacro Log "ERRO: falha ao registrar o serviço do Windows"
    MessageBox MB_ICONSTOP "Não foi possível registrar o serviço do Windows (código $0)."
    Abort
  ${EndIf}
  !insertmacro Servico "start"
  StrCpy $R9 $0
  Sleep 4000
  !insertmacro Servico "status"
  Sleep 3000
  !insertmacro Rodar "Testando se a API responde em http://localhost:$ApiPort/" '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "try { $$r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 http://127.0.0.1:$ApiPort/; Write-Output (\"API respondeu: HTTP \" + $$r.StatusCode + \" \" + $$r.Content) } catch { Write-Output (\"API NAO respondeu: \" + $$_.Exception.Message); exit 1 }"'
  ${If} $0 != 0
    StrCpy $8 "erro"
    !insertmacro Log "AVISO: a API ainda não respondeu; veja as últimas linhas do registro do serviço abaixo"
  ${EndIf}
  !insertmacro Rodar "Últimas linhas do registro do serviço (logs\api.log)" '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath \"$INSTDIR\logs\api.log\") { Get-Content -Tail 20 -LiteralPath \"$INSTDIR\logs\api.log\" } else { Write-Output \"(registro ainda nao criado)\" }"'
  StrCpy $0 $R9
  ${If} $0 != 0
  ${AndIf} $8 == "ok"
    MessageBox MB_ICONEXCLAMATION "O serviço foi registrado, mas não iniciou (código $0).$\r$\nVeja o atalho $\"Ver registro de funcionamento$\" no Menu Iniciar."
  ${EndIf}

  ; ---- atalhos (para todos os usuários) ----
  CreateDirectory "$SMPROGRAMS\${APP_NOME}"
  WriteINIStr "$SMPROGRAMS\${APP_NOME}\Documentação da API.url" "InternetShortcut" "URL" "http://localhost:$ApiPort/docs"
  !insertmacro AtalhoAdmin "$SMPROGRAMS\${APP_NOME}\Reiniciar API.lnk" "${SERVICO}" "restart"
  !insertmacro AtalhoAdmin "$SMPROGRAMS\${APP_NOME}\Parar API.lnk" "${SERVICO}" "stop"
  !insertmacro AtalhoAdmin "$SMPROGRAMS\${APP_NOME}\Iniciar API.lnk" "${SERVICO}" "start"
  !insertmacro AtalhoAdmin "$SMPROGRAMS\${APP_NOME}\Configurar conexão.lnk" "$WINDIR\notepad.exe" "$INSTDIR\.env"
  CreateShortCut "$SMPROGRAMS\${APP_NOME}\Ver registro de funcionamento.lnk" "$WINDIR\notepad.exe" '"$INSTDIR\logs\api.log"'
  CreateShortCut "$SMPROGRAMS\${APP_NOME}\Pasta da API.lnk" "$INSTDIR"
  CreateShortCut "$SMPROGRAMS\${APP_NOME}\Desinstalar.lnk" "$INSTDIR\Desinstalar.exe"

  ; ---- registro no Windows (Aplicativos instalados) ----
  WriteRegStr HKLM "Software\${APP_ID}" "PastaInstalacao" "$INSTDIR"
  WriteRegStr HKLM "Software\${APP_ID}" "PortaApi" "$ApiPort"
  WriteUninstaller "$INSTDIR\Desinstalar.exe"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${APP_NOME}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${APP_VERSAO}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${APP_NOME}"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Desinstalar.exe"'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" "$0"

  CreateShortCut "$SMPROGRAMS\${APP_NOME}\Ver registro da instalação.lnk" "$WINDIR\notepad.exe" '"$LOG"'
  ${If} $8 == "ok"
    !insertmacro Log "INSTALAÇÃO CONCLUÍDA COM SUCESSO"
  ${Else}
    !insertmacro Log "INSTALAÇÃO CONCLUÍDA COM AVISOS (veja acima)"
    MessageBox MB_ICONINFORMATION "Detalhes de tudo o que foi feito estão em:$\r$\n$LOG"
  ${EndIf}
  CopyFiles /SILENT "$LOG" "$INSTDIR\logs\instalacao.txt"
SectionEnd

Section /o "Atalho da documentação na Área de Trabalho" SecDesk
  SetShellVarContext all
  WriteINIStr "$DESKTOP\${APP_NOME}.url" "InternetShortcut" "URL" "http://localhost:$ApiPort/docs"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "Arquivos da API, ambiente Python, banco de dados e o serviço do Windows (início automático com o computador)."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesk} "Cria na Área de Trabalho um atalho para a página de documentação da API."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function AbrirDocumentacao
  Sleep 2000
  ExecShell "open" "http://localhost:$ApiPort/docs"
FunctionEnd

; ---------------------------------------------------------------- Desinstalação
Function un.onInit
  SetShellVarContext all
  SetRegView 64
  !insertmacro IniciarLog
FunctionEnd

Section "Uninstall"
  ${If} ${FileExists} "${SERVICO}"
    !insertmacro unLog "Desinstalação da ${APP_NOME}: parando e removendo o serviço"
    !insertmacro unServico "stop"
    Sleep 2000
    !insertmacro unServico "uninstall"
    Sleep 1000
  ${EndIf}
  Delete "$DESKTOP\${APP_NOME}.url"
  RMDir /r "$SMPROGRAMS\${APP_NOME}"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "Software\${APP_ID}"
  !insertmacro unLog "Desinstalação concluída (bancos de dados mantidos)"
  MessageBox MB_ICONINFORMATION "A ${APP_NOME} foi removida.$\r$\n$\r$\nO banco de dados e os cadastros no PostgreSQL foram mantidos."
SectionEnd
