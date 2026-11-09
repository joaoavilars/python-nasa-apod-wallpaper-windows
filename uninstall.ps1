<#
.SYNOPSIS
  Remove a tarefa agendada do NASA APOD Wallpaper. Não apaga imagens, config.json nem logs.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveEventSource
#>
[CmdletBinding()]
param(
    [string]$TaskName = 'Download NASA APOD',
    [switch]$RemoveEventSource,   # também remove a origem de eventos e a visão (pede UAC)
    [switch]$DryRun,
    [switch]$OnlyEventSource      # interno: passo elevado
)

$ErrorActionPreference = 'Stop'
$EventSource = 'NASA-APOD-Wallpaper'
$EventKey = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\$EventSource"
$ViewFile = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views\NASA_APOD_Wallpaper.xml'

function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($OnlyEventSource) {
    if (Test-Path $EventKey) { Remove-Item $EventKey -Recurse -Force }
    if (Test-Path $ViewFile) { Remove-Item $ViewFile -Force }
    return
}

Write-Host "==> Removendo a tarefa '$TaskName'" -ForegroundColor Cyan
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) { Write-Host '    Tarefa não encontrada (nada a fazer).' }
elseif ($DryRun) { Write-Host '    [dry-run] a tarefa seria removida.' -ForegroundColor Yellow }
else {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host '    Tarefa removida.' -ForegroundColor Green
}

if ($RemoveEventSource) {
    Write-Host "==> Removendo a origem de eventos '$EventSource'" -ForegroundColor Cyan
    if ($DryRun) { Write-Host '    [dry-run] a origem e a visão seriam removidas.' -ForegroundColor Yellow }
    elseif (Test-Admin) {
        if (Test-Path $EventKey) { Remove-Item $EventKey -Recurse -Force }
        if (Test-Path $ViewFile) { Remove-Item $ViewFile -Force }
        Write-Host '    Removida.' -ForegroundColor Green
    } else {
        $psExe = (Get-Process -Id $PID).Path
        Start-Process $psExe -Verb RunAs -Wait -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-OnlyEventSource')
        Write-Host '    Concluído.' -ForegroundColor Green
    }
}
Write-Host 'Pronto. Imagens, config.json e logs foram mantidos.'
