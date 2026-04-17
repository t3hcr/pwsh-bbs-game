Set-StrictMode -Version Latest

function New-BbsGameTime {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Day = 1
        Hour = 0
    }
}

function Advance-BbsTime {
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
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$Time)

    $hh = $Time.Hour.ToString('00')
    "Day $($Time.Day), $($hh):00"
}
