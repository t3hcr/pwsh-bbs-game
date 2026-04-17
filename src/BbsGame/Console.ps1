Set-StrictMode -Version Latest

function Set-BbsConsoleTheme {
    [CmdletBinding()]
    param([switch]$NoColor)

    if ($NoColor) {
        $script:BbsTheme = @{ Accent = $null; Good = $null; Warn = $null; Bad = $null; Dim = $null }
        return
    }

    $script:BbsTheme = @{ Accent = 'Cyan'; Good = 'Green'; Warn = 'Yellow'; Bad = 'Red'; Dim = 'DarkGray' }
}

function Write-BbsLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter()][ValidateSet('Accent','Good','Warn','Bad','Dim','None')][string]$Tone = 'None'
    )

    $color = $null
    if ($Tone -ne 'None' -and $script:BbsTheme.ContainsKey($Tone)) { $color = $script:BbsTheme[$Tone] }

    if ($null -ne $color) { Write-Host $Text -ForegroundColor $color }
    else { Write-Host $Text }
}

function Read-BbsChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string[]]$Options,
        [Parameter()][string]$Default
    )

    while ($true) {
        $optText = ($Options | ForEach-Object { "[$_]" }) -join ' '
        $raw = Read-Host "$Prompt $optText"
        if ([string]::IsNullOrWhiteSpace($raw)) {
            if (-not [string]::IsNullOrWhiteSpace($Default) -and ($Options -contains $Default)) {
                return $Default
            }
            continue
        }

        $val = $raw.Trim()
        if ($Options -contains $val) { return $val }

        Write-BbsLine "Invalid choice: $val" -Tone Warn
    }
}

function Read-BbsInt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter()][int]$Min = [int]::MinValue,
        [Parameter()][int]$Max = [int]::MaxValue
    )

    while ($true) {
        $raw = Read-Host $Prompt
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge $Min -and $n -le $Max) { return $n }
        Write-BbsLine "Enter a number between $Min and $Max." -Tone Warn
    }
}
