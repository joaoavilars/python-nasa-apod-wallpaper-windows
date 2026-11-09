<#
.SYNOPSIS
  Instala o NASA APOD Wallpaper: dependências, config.json, Log de Eventos e tarefa agendada.

.DESCRIPTION
  1. Localiza o Python e instala as dependências (requirements.txt).
  2. Cria o config.json a partir do config.example.json (se ainda não existir).
  3. Registra a origem "NASA-APOD-Wallpaper" no Log de Eventos do Windows e instala a visão
     personalizada do Visualizador de Eventos (pede elevação/UAC apenas para este passo).
  4. Cria a tarefa agendada (diária + no logon), executando pythonw.exe sem abrir janela.

  Use -DryRun para ver o que seria feito sem alterar nada.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Time 07:30 -NoRun
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$Time = '09:00',                    # horário diário (HH:mm)
    [string]$TaskName = 'Download NASA APOD',   # nome da tarefa agendada
    [string]$PythonPath,                        # caminho do python.exe (detectado se omitido)
    [string]$DownloadDir,                       # pasta das imagens (pergunta se omitido)
    [switch]$Yes,                               # aceita os valores sugeridos sem perguntar
    [switch]$NoInstallPython,                   # não oferece instalar o Python se ausente
    [switch]$NoEventLog,                       # não registra no Log de Eventos
    [switch]$NoRun,                             # não executa a tarefa ao final (padrão: executa)
    [switch]$RunNow,                            # (legado) agora é o padrão
    [switch]$Force,                             # substitui a tarefa se já existir
    [switch]$DryRun,                            # só mostra o que seria feito
    [switch]$OnlyEventSource                    # interno: passo elevado
)

$ErrorActionPreference = 'Stop'
$ProjectDir  = $PSScriptRoot
$EventSource = 'NASA-APOD-Wallpaper'
$EventKey    = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\$EventSource"
$ViewsDir    = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'
$ViewFile    = Join-Path $ViewsDir 'NASA_APOD_Wallpaper.xml'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    [dry-run] $msg" -ForegroundColor Yellow }

function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Register-ApodEventSource {
    # EventCreate.exe traz uma tabela de mensagens "%1" para os IDs 1-1000: o texto do evento aparece limpo.
    New-Item -Path $EventKey -Force | Out-Null
    New-ItemProperty -Path $EventKey -Name EventMessageFile -Value '%SystemRoot%\System32\EventCreate.exe' `
        -PropertyType ExpandString -Force | Out-Null
    New-ItemProperty -Path $EventKey -Name TypesSupported -Value 7 -PropertyType DWord -Force | Out-Null
    if (-not (Test-Path $ViewsDir)) { New-Item -ItemType Directory -Path $ViewsDir -Force | Out-Null }
    Copy-Item (Join-Path $ProjectDir 'EventViewer_NASA_APOD.xml') $ViewFile -Force
}

function Resolve-Python {
    $candidates = @()
    if ($PythonPath) {
        $candidates += $PythonPath
    } else {
        $candidates += @(Get-Command python.exe -All -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -notlike '*\WindowsApps\*' } | ForEach-Object { $_.Source })
        if (Get-Command py.exe -ErrorAction SilentlyContinue) { $candidates += 'py.exe' }
    }
    foreach ($c in $candidates) {
        try {
            $pyArgs = if ($c -like '*py.exe') { @('-3', '-c', 'import sys;print(sys.executable)') } else { @('-c', 'import sys;print(sys.executable)') }
            # Capturar toda a saída antes de filtrar: "| Select -First 1" mataria o processo (exit code -1)
            $out = @(& $c @pyArgs 2>$null)
            $code = $LASTEXITCODE
            $exe = if ($out.Count) { "$($out[0])".Trim() } else { $null }
            if ($code -eq 0 -and $exe -and (Test-Path $exe)) { return $exe }
        } catch { }
    }
    # Instalações recém-feitas podem não estar no PATH da sessão atual: procura nos locais padrão
    $roots = @("$env:LOCALAPPDATA\Programs\Python", "$env:ProgramFiles", "${env:ProgramFiles(x86)}")
    foreach ($r in $roots) {
        if (-not $r -or -not (Test-Path $r)) { continue }
        $found = Get-ChildItem -Path $r -Directory -Filter 'Python3*' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'python.exe' } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($found) { return $found }
    }
    return $null
}

function Install-Python {
    # Instala o Python 3 para o usuário atual (sem UAC): primeiro via winget, depois baixando do python.org.
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host '    Instalando via winget...' -ForegroundColor Yellow
        & $winget.Source install --id Python.Python.3.12 -e --scope user --silent `
            --accept-package-agreements --accept-source-agreements | Out-Host   # Out-Host: não contaminar o valor de retorno
        $py = Resolve-Python
        if ($py) { return [string]$py }
        Write-Warning 'winget não concluiu a instalação; tentando o instalador do python.org.'
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $ver = '3.12.10'
    $url = "https://www.python.org/ftp/python/$ver/python-$ver-$arch.exe"
    $installer = Join-Path $env:TEMP "python-$ver-$arch.exe"
    Write-Host "    Baixando $url" -ForegroundColor Yellow
    $oldProgress = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'   # acelera o download no PS 5.1
    try { Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing }
    finally { $ProgressPreference = $oldProgress }
    Write-Host '    Executando o instalador (silencioso, apenas para o usuário atual)...' -ForegroundColor Yellow
    $p = Start-Process -FilePath $installer -Wait -PassThru -ArgumentList `
        '/quiet', 'InstallAllUsers=0', 'PrependPath=1', 'Include_test=0', 'Include_launcher=1'
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) { throw "O instalador do Python terminou com código $($p.ExitCode)." }
    return [string](Resolve-Python)
}

# --- Passo elevado (chamado pelo próprio instalador via UAC) ---
if ($OnlyEventSource) {
    Register-ApodEventSource
    Write-Ok "Origem de eventos '$EventSource' registrada."
    return
}

# --- Validações ---
try { [void][datetime]::ParseExact($Time, 'HH:mm', $null) }
catch { throw "Horário inválido: '$Time'. Use o formato HH:mm (ex.: 09:00)." }

if ($DryRun) { Write-Host 'MODO DRY-RUN: nada será alterado.' -ForegroundColor Yellow }

# 1. Python e dependências
Write-Step 'Procurando o Python'
$python = Resolve-Python
if (-not $python) {
    $msg = 'Python 3 não encontrado. Instale em https://www.python.org/downloads/ (marque "Add to PATH") ou use -PythonPath.'
    if ($PythonPath -or $NoInstallPython) { throw $msg }
    if ($DryRun) { Write-Skip 'Python não encontrado: seria instalado automaticamente (winget ou python.org)' ; return }
    $go = $Yes -or -not [Environment]::UserInteractive
    if (-not $go) {
        $a = Read-Host '    Python 3 não encontrado. Baixar e instalar agora (somente para o seu usuário)? [S/n]'
        $go = ([string]::IsNullOrWhiteSpace($a) -or $a -match '^[sSyY]')
    }
    if (-not $go) { throw $msg }
    Write-Step 'Instalando o Python 3'
    $python = @(Install-Python | Where-Object { $_ })[-1]
    if (-not $python) { throw 'Python instalado, mas não localizado. Abra um novo PowerShell e rode o instalador novamente.' }
}
$pythonw = Join-Path (Split-Path $python) 'pythonw.exe'
if (-not (Test-Path $pythonw)) { $pythonw = $python }
Write-Ok "Python: $python"

Write-Step 'Instalando dependências (requirements.txt)'
if ($DryRun) { Write-Skip "$python -m pip install -r requirements.txt" }
else {
    & $python -m pip install --disable-pip-version-check --quiet -r (Join-Path $ProjectDir 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependências com o pip.' }
    Write-Ok 'Dependências instaladas.'
}

# 2. config.json
Write-Step 'Verificando config.json'
$cfg = Join-Path $ProjectDir 'config.json'
if (Test-Path $cfg) { Write-Ok 'config.json já existe (mantido).' }
elseif ($DryRun)    { Write-Skip 'copiaria config.example.json para config.json' }
else {
    Copy-Item (Join-Path $ProjectDir 'config.example.json') $cfg
    Write-Ok 'config.json criado a partir do exemplo. Edite-o para mudar a pasta das imagens.'
}

# 2b. Pasta de download das imagens
Write-Step 'Definindo a pasta das imagens'
$current = $null
if (Test-Path $cfg) {
    try { $current = (Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json).download_dir } catch { }
}
if ($current) { $suggested = [Environment]::ExpandEnvironmentVariables($current) }
else { $suggested = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'nasa' }

$chosen = $DownloadDir
if (-not $chosen) {
    if ($Yes -or $DryRun -or -not [Environment]::UserInteractive) { $chosen = $suggested }
    else {
        while ($true) {
            $answer = Read-Host "    Pasta para salvar as imagens [$suggested] (Enter para confirmar)"
            $chosen = if ([string]::IsNullOrWhiteSpace($answer)) { $suggested } else { $answer.Trim().Trim('"') }
            $expanded = [Environment]::ExpandEnvironmentVariables($chosen)
            if (-not [IO.Path]::IsPathRooted($expanded)) { Write-Warning 'Informe um caminho completo (ex.: D:\Imagens\NASA).'; continue }
            break
        }
    }
}
$chosenFull = [Environment]::ExpandEnvironmentVariables($chosen)
if (-not [IO.Path]::IsPathRooted($chosenFull)) { throw "A pasta das imagens deve ser um caminho completo: '$chosen'" }

if ($DryRun) { Write-Skip "gravaria download_dir = $chosen no config.json e criaria a pasta se necessário" }
else {
    if (-not (Test-Path $chosenFull)) { New-Item -ItemType Directory -Path $chosenFull -Force | Out-Null }
    $json = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
    $json.download_dir = $chosen
    # UTF-8 sem BOM: o Python não lê JSON com BOM
    [IO.File]::WriteAllText($cfg, ($json | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
    Write-Ok "Pasta das imagens: $chosenFull"
}

# 3. Log de Eventos
if (-not $NoEventLog) {
    Write-Step "Registrando a origem '$EventSource' no Log de Eventos"
    if (Test-Path $EventKey) { Write-Ok 'Origem já registrada.' }
    elseif ($DryRun) { Write-Skip 'registraria a origem (requer administrador / UAC)' }
    else {
        if (Test-Admin) { Register-ApodEventSource }
        else {
            Write-Host '    Será exibido um pedido de permissão (UAC) apenas para este passo.' -ForegroundColor Yellow
            $psExe = (Get-Process -Id $PID).Path
            try {
                Start-Process $psExe -Verb RunAs -Wait -ArgumentList @(
                    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-OnlyEventSource')
            } catch { Write-Warning "Elevação cancelada: $($_.Exception.Message)" }
        }
        if (Test-Path $EventKey) { Write-Ok 'Origem registrada. Visão "NASA APOD Wallpaper" disponível no Visualizador de Eventos.' }
        else { Write-Warning 'Origem não registrada. Os eventos ainda são gravados, mas sem texto formatado. Rode o instalador novamente como administrador.' }
    }
}

# 4. Tarefa agendada
Write-Step "Criando a tarefa agendada '$TaskName'"
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing -and -not $Force) {
    $msg = "A tarefa '$TaskName' já existe. Use -Force para substituí-la ou -TaskName para outro nome."
    if ($DryRun) { Write-Warning $msg } else { throw $msg }
}
$user = "$env:USERDOMAIN\$env:USERNAME"
if ($DryRun) {
    Write-Skip "tarefa '$TaskName' para ${user}: diária às $Time + 1 min após o logon"
    Write-Skip "ação: $pythonw `"$ProjectDir\get_wall_day.py`" (pasta: $ProjectDir)"
    if ($existing) { Write-Skip 'a tarefa existente seria substituída (-Force)' }
} else {
    $action    = New-ScheduledTaskAction -Execute $pythonw -Argument "`"$ProjectDir\get_wall_day.py`"" -WorkingDirectory $ProjectDir
    $daily     = New-ScheduledTaskTrigger -Daily -At $Time
    $logon     = New-ScheduledTaskTrigger -AtLogOn -User $user
    $logon.Delay = 'PT1M'
    $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
                    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($daily, $logon) `
        -Settings $settings -Principal $principal -Force `
        -Description 'Baixa o NASA APOD do dia e aplica como papel de parede.' | Out-Null
    Write-Ok "Tarefa criada: diária às $Time e 1 minuto após o logon."
}

if (-not $NoRun) {
    Write-Step 'Executando agora'
    if ($DryRun) { Write-Skip "Start-ScheduledTask '$TaskName'" }
    else { Start-ScheduledTask -TaskName $TaskName; Write-Ok 'Tarefa iniciada.' }
}

Write-Host ''
Write-Host 'Concluído.' -ForegroundColor Green
Write-Host "  Configuração : $cfg"
Write-Host "  Arquivo de log: $env:LOCALAPPDATA\nasa-apod-wallpaper\apod.log"
Write-Host "  Eventos      : Visualizador de Eventos > Modos de Exibição Personalizados > NASA APOD Wallpaper"
