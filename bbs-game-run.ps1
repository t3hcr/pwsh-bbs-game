#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter()][switch]$NoColor,
    [Parameter()][string]$SavePath = "./saves/save.json",

    # Scriptable mode (no prompts): advances simulation then exits.
    [Parameter()][int]$SimDays = 0,
    [Parameter()][switch]$NewGame,
    [Parameter()][string]$NewGameName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

trap {
    try {
        $logDir = Join-Path $script:ProjectRoot 'saves'
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir | Out-Null
        }

        $logPath = Join-Path $logDir 'last-crash.txt'
        $lines = @(
            ("BBS Tycoon crashed: {0}" -f $_.Exception.Message)
        )
        if ($_.InvocationInfo) { $lines += $_.InvocationInfo.PositionMessage }
        if ($_.ScriptStackTrace) { $lines += ""; $lines += $_.ScriptStackTrace }
        Set-Content -LiteralPath $logPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
    } catch {
        # Best-effort logging only.
    }

    [Console]::Error.WriteLine("BBS Tycoon crashed: {0}" -f $_.Exception.Message)
    if ($_.InvocationInfo) { [Console]::Error.WriteLine($_.InvocationInfo.PositionMessage) }
    if ($_.ScriptStackTrace) { [Console]::Error.WriteLine($_.ScriptStackTrace) }
    exit 1
}

. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Console.ps1')
. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Time.ps1')
. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Data.ps1')
. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Model.ps1')
. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Simulation.ps1')
. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Save.ps1')
. (Join-Path $script:ProjectRoot 'src' 'BbsGame' 'Game.ps1')

if ($NoColor) { Set-BbsConsoleTheme -NoColor }

Start-BbsGame -SavePath $SavePath -SimDays $SimDays -NewGame:$NewGame -NewGameName $NewGameName
