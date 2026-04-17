Set-StrictMode -Version Latest

function Ensure-BbsSaveDir {
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
