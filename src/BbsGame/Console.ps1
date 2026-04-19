<#
.SYNOPSIS
Console input/output helpers for BBS Tycoon.

.DESCRIPTION
Defines small helper functions used by the game to read user input and write
styled output. This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Console.ps1')
Set-BbsConsoleTheme
Write-BbsLine "Welcome" -Tone Accent

.NOTES
These helpers write to the host (interactive console), not to the pipeline.
#>

Set-StrictMode -Version Latest

function Set-BbsConsoleTheme {
    <#
    .SYNOPSIS
    Configures the color theme used by other console helpers.

    .DESCRIPTION
    Sets a script-scoped `$script:BbsTheme` hashtable used by `Write-BbsLine`.
    Use `-NoColor` to disable colors entirely.

    .PARAMETER NoColor
    Disables theme colors (output is written without `-ForegroundColor`).

    .EXAMPLE
    Set-BbsConsoleTheme

    Enables the default color theme.

    .EXAMPLE
    Set-BbsConsoleTheme -NoColor

    Disables colored output.

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param([switch]$NoColor)

    if ($NoColor) {
        $script:BbsTheme = @{ Accent = $null; Good = $null; Warn = $null; Bad = $null; Dim = $null }
        return
    }

    $script:BbsTheme = @{ Accent = 'Cyan'; Good = 'Green'; Warn = 'Yellow'; Bad = 'Red'; Dim = 'DarkGray' }
}

function Write-BbsLine {
    <#
    .SYNOPSIS
    Writes a single line of text to the console.

    .DESCRIPTION
    Writes the provided text to the host. If a theme color is configured and the
    supplied tone maps to a color, the text is written using `-ForegroundColor`.

    .PARAMETER Text
    The text to display. May be an empty string.

    .PARAMETER Tone
    A semantic tone that maps to a theme color. Valid values are: Accent, Good,
    Warn, Bad, Dim, None.

    .EXAMPLE
    Write-BbsLine "Saved." -Tone Good

    Writes a success message in the configured theme.

    .EXAMPLE
    Write-BbsLine "" 

    Writes a blank line.

    .OUTPUTS
    None.
    #>
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
    <#
    .SYNOPSIS
    Prompts the user to choose a value from a fixed list.

    .DESCRIPTION
    Prompts using `Read-Host` until the user enters a value that is present in
    `-Options`. If the user presses Enter with no input, `-Default` is returned
    when it is present in `-Options`.

    .PARAMETER Prompt
    Prompt text displayed to the user.

    .PARAMETER Options
    The allowed choices.

    .PARAMETER Default
    Optional default choice used when the user provides no input.

    .EXAMPLE
    Read-BbsChoice -Prompt "Choose" -Options @('1','2','Q') -Default '1'

    Returns one of the allowed values.

    .OUTPUTS
    System.String.
    #>
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
    <#
    .SYNOPSIS
    Prompts the user for an integer within a range.

    .DESCRIPTION
    Prompts using `Read-Host` until the input parses as an integer and falls
    within the inclusive bounds of `-Min` and `-Max`.

    .PARAMETER Prompt
    Prompt text displayed to the user.

    .PARAMETER Min
    Minimum allowed value (inclusive).

    .PARAMETER Max
    Maximum allowed value (inclusive).

    .EXAMPLE
    Read-BbsInt -Prompt "How many lines?" -Min 1 -Max 8

    Returns a validated integer.

    .OUTPUTS
    System.Int32.
    #>
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
