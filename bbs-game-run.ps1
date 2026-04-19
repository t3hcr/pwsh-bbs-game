#!/usr/bin/env pwsh
<#
.SYNOPSIS
Runs the BBS Tycoon console game.

.DESCRIPTION
Starts an interactive single-player console game about running a dial-up era BBS.

The script dot-sources supporting scripts under `src/BbsGame/*.ps1`, then calls
`Start-BbsGame`.

If the game encounters an unhandled error, it writes a best-effort crash log to
`./saves/last-crash.txt` and exits with code 1.

.PARAMETER NoColor
Disables colored console output.

.PARAMETER SavePath
Path to a JSON save file. Relative paths are interpreted from the current working
directory. Default is `./saves/save.json`.

.PARAMETER SimDays
Runs the simulation for the specified number of in-game days without prompting,
saves, prints a short summary, and exits.

.PARAMETER NewGame
Starts a new game even if `-SavePath` already exists.

.PARAMETER NewGameName
Name to use for a new game. If not provided, the script prompts (interactive
mode) or uses a default.

.EXAMPLE
pwsh ./bbs-game-run.ps1

Starts the game interactively using the default save path.

.EXAMPLE
pwsh ./bbs-game-run.ps1 -NewGame -NewGameName "The Rusty Modem" -SimDays 30 -SavePath ./saves/test.json

Creates a new game, advances 30 days without prompts, then saves to the specified
path.

.NOTES
Requires PowerShell 7+.
#>
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
