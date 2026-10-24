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
Var DbHost
Var DbPort
Var DbUser
Var DbPass
Var DbName
Var ApiPort
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

Function .onInit
  SetShellVarContext all
  SetRegView 64
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
    MessageBox MB_YESNO|MB_ICONEXCLAMATION "Não encontrei o Python 3.12, 3.13 ou 3.14 neste computador.$\r$\n$\r$\nA API precisa dele para funcionar. Deseja abrir o site python.org para baixá-lo?$\r$\n(Depois de instalar o Python, rode este instalador de novo.)" IDNO +2
      ExecShell "open" "https://www.python.org/downloads/windows/"
    Abort
  ${EndIf}

  ; valores padrão da página de conexão
  StrCpy $DbHost "localhost"
  StrCpy $DbPort "5432"
  StrCpy $DbUser "postgres"
  StrCpy $DbPass ""
  StrCpy $DbName "api_db"
  StrCpy $ApiPort "8000"
FunctionEnd

; ---------------------------------------------------------------- Página do banco
Function PaginaBanco
  !insertmacro MUI_HEADER_TEXT "Conexão com o PostgreSQL" "Informe onde está o banco de dados que a API vai usar."
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 20u "A API cria o banco abaixo (se não existir) e as tabelas dela. Nenhum outro banco é alterado."
  Pop $0

  ${NSD_CreateLabel} 0 26u 30% 12u "Servidor:"
  Pop $0
  ${NSD_CreateText} 32% 24u 45% 12u "$DbHost"
  Pop $hHost
  ${NSD_CreateLabel} 0 44u 30% 12u "Porta:"
  Pop $0
  ${NSD_CreateNumber} 32% 42u 20% 12u "$DbPort"
  Pop $hPort
  ${NSD_CreateLabel} 0 62u 30% 12u "Usuário:"
  Pop $0
  ${NSD_CreateText} 32% 60u 45% 12u "$DbUser"
  Pop $hUser
  ${NSD_CreateLabel} 0 80u 30% 12u "Senha:"
  Pop $0
  ${NSD_CreatePassword} 32% 78u 45% 12u "$DbPass"
  Pop $hPass
  ${NSD_CreateLabel} 0 98u 30% 12u "Nome do banco da API:"
  Pop $0
  ${NSD_CreateText} 32% 96u 45% 12u "$DbName"
  Pop $hName
  ${NSD_CreateLabel} 0 116u 30% 12u "Porta da API:"
  Pop $0
  ${NSD_CreateNumber} 32% 114u 20% 12u "$ApiPort"
  Pop $hApiPort
  ${NSD_CreateLabel} 0 134u 100% 12u "A API ficará em http://localhost:<porta da API>/docs"
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
  ${NSD_GetText} $hApiPort $ApiPort
  ${If} $DbHost == ""
  ${OrIf} $DbPort == ""
  ${OrIf} $DbUser == ""
  ${OrIf} $DbName == ""
  ${OrIf} $ApiPort == ""
    MessageBox MB_ICONEXCLAMATION "Preencha servidor, porta, usuário, nome do banco e porta da API."
    Abort
  ${EndIf}
  ${If} $DbPass == ""
    MessageBox MB_YESNO|MB_ICONQUESTION "A senha está em branco. Continuar mesmo assim?" IDYES +2
    Abort
  ${EndIf}
FunctionEnd

; ---------------------------------------------------------------- Instalação
; Executa um comando do serviço (install, start, stop, uninstall...) e devolve o código em $0
!macro Servico ACAO
  nsExec::ExecToLog '"${SERVICO}" ${ACAO}'
  Pop $0
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
  ${If} ${FileExists} "${SERVICO}"
    DetailPrint "Parando o serviço da versão anterior..."
    !insertmacro Servico "stop"
    Sleep 2000
    !insertmacro Servico "uninstall"
    Sleep 1000
  ${EndIf}

  DetailPrint "Python encontrado: $PY"
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

  ; ---- arquivo de configuração (.env) ----
  ; senha entre aspas simples; escapa \ e ' no formato do python-dotenv
  ${WordReplace} "$DbPass" "\" "\\" "+" $1
  ${WordReplace} "$1" "'" "\'" "+" $1
  DetailPrint "Gravando configuração..."
  FileOpen $9 "$INSTDIR\.env" w
  FileWrite $9 "# Configuração da API de Cadastros (gerada pelo instalador)$\r$\n"
  FileWrite $9 "# Depois de alterar, use o atalho $\"Reiniciar API$\" no Menu Iniciar.$\r$\n"
  FileWrite $9 "DB_HOST=$DbHost$\r$\n"
  FileWrite $9 "DB_PORT=$DbPort$\r$\n"
  FileWrite $9 "DB_USER=$DbUser$\r$\n"
  FileWrite $9 "DB_PASSWORD='$1'$\r$\n"
  FileWrite $9 "DB_NAME=$DbName$\r$\n"
  FileWrite $9 "DB_TEST_NAME=api_test$\r$\n"
  FileWrite $9 "API_HOST=127.0.0.1$\r$\n"
  FileWrite $9 "API_PORT=$ApiPort$\r$\n"
  FileClose $9
  ; a senha fica legível só para administradores e para o serviço (SYSTEM)
  nsExec::ExecToLog 'icacls "$INSTDIR\.env" /inheritance:r /grant:r *S-1-5-32-544:F *S-1-5-18:F'
  Pop $0

  ; ---- ambiente Python ----
  ${IfNot} ${FileExists} "$INSTDIR\.venv\Scripts\python.exe"
    DetailPrint "Criando ambiente Python (pode levar alguns segundos)..."
    nsExec::ExecToLog '"$PY" -m venv "$INSTDIR\.venv"'
    Pop $0
    ${If} $0 != 0
      MessageBox MB_ICONSTOP "Não foi possível criar o ambiente Python (código $0)."
      Abort
    ${EndIf}
  ${EndIf}

  DetailPrint "Instalando componentes (sem internet)..."
  nsExec::ExecToLog '"$INSTDIR\.venv\Scripts\python.exe" -m pip install --no-index --find-links "$INSTDIR\wheels" --disable-pip-version-check -q -r "$INSTDIR\requirements.txt"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "Falha ao instalar os componentes da API (código $0). Veja os detalhes nesta janela."
    Abort
  ${EndIf}

  ; ---- banco de dados ----
  StrCpy $8 "ok"
  DetailPrint "Conectando ao PostgreSQL e preparando o banco $DbName..."
  nsExec::ExecToLog '"$INSTDIR\.venv\Scripts\python.exe" "$INSTDIR\preparar_bancos.py" --instalador'
  Pop $0
  ${If} $0 == 2
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "A API foi instalada, mas o PostgreSQL recusou o usuário ou a senha.$\r$\n$\r$\nUse o atalho $\"Configurar conexão$\" no Menu Iniciar para corrigir e depois $\"Reiniciar API$\"."
  ${ElseIf} $0 == 3
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "A API foi instalada, mas não encontrei o PostgreSQL em $DbHost:$DbPort.$\r$\n$\r$\nConfira se o servidor está ligado e use o atalho $\"Configurar conexão$\" para ajustar."
  ${ElseIf} $0 != 0
    StrCpy $8 "erro"
    MessageBox MB_ICONEXCLAMATION "A API foi instalada, mas houve um erro ao preparar o banco (código $0). Veja os detalhes nesta janela."
  ${EndIf}

  ; ---- serviço do Windows ----
  DetailPrint "Registrando o serviço do Windows $\"${APP_NOME}$\"..."
  !insertmacro Servico "install"
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "Não foi possível registrar o serviço do Windows (código $0)."
    Abort
  ${EndIf}
  DetailPrint "Iniciando o serviço..."
  !insertmacro Servico "start"
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
FunctionEnd

Section "Uninstall"
  ${If} ${FileExists} "${SERVICO}"
    DetailPrint "Parando e removendo o serviço..."
    !insertmacro Servico "stop"
    Sleep 2000
    !insertmacro Servico "uninstall"
    Sleep 1000
  ${EndIf}
  Delete "$DESKTOP\${APP_NOME}.url"
  RMDir /r "$SMPROGRAMS\${APP_NOME}"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "Software\${APP_ID}"
  MessageBox MB_ICONINFORMATION "A ${APP_NOME} foi removida.$\r$\n$\r$\nO banco de dados e os cadastros no PostgreSQL foram mantidos."
SectionEnd
