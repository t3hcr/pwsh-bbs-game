<#
.SYNOPSIS
Save/load helpers for BBS Tycoon.

.DESCRIPTION
Defines functions to persist game state to a JSON file and load it back.

This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Save.ps1')
$state = New-BbsState -BbsName 'Test'
Save-BbsState -State $state -SavePath ./saves/test.json
$loaded = Load-BbsState -SavePath ./saves/test.json

.OUTPUTS
This script defines functions; it does not output anything when dot-sourced.
#>

Set-StrictMode -Version Latest

function Ensure-BbsSaveDir {
    <#
    .SYNOPSIS
    Ensures the save directory exists for a given save path.

    .DESCRIPTION
    Creates the parent directory of `-SavePath` if it does not already exist.
    If `-SavePath` is relative, it is resolved relative to the current working
    directory.

    .PARAMETER SavePath
    The path to a JSON save file.

    .EXAMPLE
    Ensure-BbsSaveDir -SavePath ./saves/save.json

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SavePath)

    $full = $SavePath
    if (-not [System.IO.Path]::IsPathRooted($full)) {
        $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $SavePath))
    }

    $dir = Split-Path -Parent $full

    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Save-BbsState {
    <#
    .SYNOPSIS
    Saves the current game state to disk as JSON.

    .DESCRIPTION
    Serializes the provided state object to JSON and writes it to `-SavePath`.
    The transient `_LastEvent` property is excluded from the saved JSON.

    .PARAMETER State
    The game state to serialize.

    .PARAMETER SavePath
    The destination save path.

    .EXAMPLE
    Save-BbsState -State $state -SavePath ./saves/save.json

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$State,
        [Parameter(Mandatory)][string]$SavePath
    )

    Ensure-BbsSaveDir -SavePath $SavePath

    $json = $State | Select-Object * -ExcludeProperty _LastEvent | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $SavePath -Value $json -Encoding UTF8
}

function Load-BbsState {
    <#
    .SYNOPSIS
    Loads a game state from a JSON save file.

    .DESCRIPTION
    Reads and parses JSON from `-SavePath`. Returns `$null` when the file does
    not exist, is empty/whitespace, or contains invalid JSON.

    .PARAMETER SavePath
    The JSON save path to load.

    .EXAMPLE
    $state = Load-BbsState -SavePath ./saves/save.json

    .OUTPUTS
    System.Management.Automation.PSCustomObject or `$null`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SavePath
    )

    if (-not (Test-Path -LiteralPath $SavePath)) { return $null }

    $raw = Get-Content -LiteralPath $SavePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

    try {
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}
