<#
.SYNOPSIS
In-game time utilities for BBS Tycoon.

.DESCRIPTION
Defines a small, simplified time model used by the simulation: day number and
hour-of-day.

This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Time.ps1')
$t = New-BbsGameTime
Advance-BbsTime -Time $t -Hours 27 | Out-Null
Format-BbsTime -Time $t

.OUTPUTS
This script defines functions; it does not output anything when dot-sourced.
#>

Set-StrictMode -Version Latest

function New-BbsGameTime {
    <#
    .SYNOPSIS
    Creates a new in-game time object.

    .DESCRIPTION
    Returns a `[pscustomobject]` with `Day` and `Hour` properties.

    .EXAMPLE
    $t = New-BbsGameTime

    .OUTPUTS
    System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Day = 1
        Hour = 0
    }
}

function Advance-BbsTime {
    <#
    .SYNOPSIS
    Advances an in-game time object by a number of hours.

    .DESCRIPTION
    Mutates the supplied `-Time` object by adding `-Hours`, carrying over hours
    into days when the hour reaches 24.

    .PARAMETER Time
    The time object to advance (must have `Day` and `Hour` properties).

    .PARAMETER Hours
    The number of hours to advance. Must be >= 0.

    .EXAMPLE
    $t = New-BbsGameTime
    Advance-BbsTime -Time $t -Hours 24 | Out-Null

    .NOTES
    Throws if `-Hours` is negative.

    .OUTPUTS
    System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Time,
        [Parameter(Mandatory)][int]$Hours
    )

    if ($Hours -lt 0) { throw "Hours must be >= 0" }

    $Time.Hour += $Hours
    while ($Time.Hour -ge 24) {
        $Time.Hour -= 24
        $Time.Day += 1
    }

    return $Time
}

function Format-BbsTime {
    <#
    .SYNOPSIS
    Formats an in-game time object as a short string.

    .DESCRIPTION
    Returns a string in the form: `Day N, HH:00`.

    .PARAMETER Time
    The time object to format.

    .EXAMPLE
    Format-BbsTime -Time (New-BbsGameTime)

    .OUTPUTS
    System.String.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$Time)

    $hh = $Time.Hour.ToString('00')
    "Day $($Time.Day), $($hh):00"
}
