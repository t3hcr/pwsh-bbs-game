<#
.SYNOPSIS
Main game loop and UI flow for BBS Tycoon.

.DESCRIPTION
Defines the main game entry function (`Start-BbsGame`) and supporting UI helpers
for showing status and applying upgrades.

This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Game.ps1')
Start-BbsGame -SavePath ./saves/save.json

.OUTPUTS
This script defines functions; it does not output anything when dot-sourced.
#>

Set-StrictMode -Version Latest

function Show-BbsStatus {
    <#
    .SYNOPSIS
    Writes a one-screen status summary to the console.

    .DESCRIPTION
    Computes derived stats and prints a summary of the current BBS state:
    users, cash, upgrades, and the last random event (if present).

    .PARAMETER State
    The current game state.

    .PARAMETER Catalog
    The game catalog returned by `Get-BbsCatalog`.

    .EXAMPLE
    Show-BbsStatus -State $state -Catalog $catalog

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$State,
        [Parameter(Mandatory)][pscustomobject]$Catalog
    )

    $d = Get-BbsDerivedStats -State $State -Catalog $Catalog
    $bbs = $State.Bbs
    $fin = $State.Finance

    Write-Host ""
    Write-BbsLine ("{0}  |  {1}" -f $bbs.Name, (Format-BbsTime $State.Time)) -Tone Accent
    Write-BbsLine ("Users: {0} / {1}   Lines: {2}   Rep: {3:P0}" -f $bbs.Users, $d.UserCap, $bbs.PhoneLines, $bbs.Reputation) -Tone None
    Write-BbsLine ('Cash: ${0:N2}   Yesterday: ${1:N2}   Lifetime: ${2:N2}' -f $fin.Cash, $fin.LastDayNet, $fin.LifetimeProfit) -Tone None

    Write-BbsLine ("Software: {0}   Pricing: {1}" -f $d.Software.Name, $d.Pricing.Name) -Tone Dim
    Write-BbsLine ("CPU: {0}   RAM: {1}MB   Disk: {2}MB" -f $d.Cpu.Name, $bbs.RamMB, $bbs.DiskMB) -Tone Dim
    Write-BbsLine ("Connectivity: {0}   Network: {1}   Doors: {2}" -f $d.Connectivity.Name, $d.Network.Name, $d.Doors.Name) -Tone Dim

    if ($State.PSObject.Properties.Name -contains '_LastEvent' -and $State._LastEvent) {
        Write-BbsLine ("Event: {0}" -f $State._LastEvent) -Tone Warn
    }
}

function Show-BbsUpgrades {
    <#
    .SYNOPSIS
    Shows the upgrades menu and applies the selected upgrade.

    .DESCRIPTION
    Displays the upgrades menu and prompts for a choice. If the player selects an
    upgrade they can afford, the function mutates the game state (cash and BBS
    configuration). This function does not save automatically.

    .PARAMETER State
    The current game state to mutate.

    .PARAMETER Catalog
    The game catalog returned by `Get-BbsCatalog`.

    .EXAMPLE
    Show-BbsUpgrades -State $state -Catalog $catalog

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$State,
        [Parameter(Mandatory)][pscustomobject]$Catalog
    )

    $bbs = $State.Bbs
    $fin = $State.Finance

    Write-Host ""
    Write-BbsLine "Upgrades" -Tone Accent
    Write-BbsLine ('Cash: ${0:N2}' -f $fin.Cash) -Tone None

    Write-Host ""
    Write-BbsLine ("1) Add phone line (+1)  (One-time: ${0:N2}, Monthly: +${1:N2})" -f 120.00, $Catalog.PhoneLine.MonthlyCostPerLine) -Tone None
    Write-BbsLine "2) Upgrade BBS software" -Tone None
    Write-BbsLine "3) Change pricing (Free/Paid)" -Tone None
    Write-BbsLine "4) Connectivity (Dial-up/Shell/Full IP)" -Tone None
    Write-BbsLine "5) Mail network (None/RIME/Fido)" -Tone None
    Write-BbsLine "6) Door games (None/Classic/Premium)" -Tone None
    Write-BbsLine "7) Hardware (CPU/RAM/Disk)" -Tone None
    Write-BbsLine "X) Back" -Tone None

    $choice = Read-BbsChoice -Prompt "Choose" -Options @('1','2','3','4','5','6','7','X')
    switch ($choice) {
        '1' {
            $cost = 120.00
            if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
            $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
            $bbs.PhoneLines += 1
            Write-BbsLine "Added a phone line. More nodes, more callers." -Tone Good
        }
        '2' {
            $tiers = $Catalog.SoftwareTiers
            $currentIdx = ($tiers | ForEach-Object Id).IndexOf($bbs.SoftwareId)
            $nextIdx = [math]::Min($tiers.Count - 1, $currentIdx + 1)
            if ($nextIdx -eq $currentIdx) { Write-BbsLine "Already at top tier." -Tone Dim; return }

            $current = $tiers[$currentIdx]
            $next = $tiers[$nextIdx]
            $oneTime = 150.00 + (110.00 * $nextIdx)
            Write-BbsLine ("Current: {0}" -f $current.Name) -Tone Dim
            Write-BbsLine ('Next: {0}  (One-time: ${1:N2}, Monthly: ${2:N2}, Cap: {3})' -f $next.Name, $oneTime, $next.BaseMonthlyCost, $next.MaxUsers) -Tone None
            if ($fin.Cash -lt $oneTime) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $oneTime, $fin.Cash) -Tone Warn; return }
            $fin.Cash = [math]::Round($fin.Cash - $oneTime, 2)
            $bbs.SoftwareId = $next.Id
            Write-BbsLine ("Upgraded software to: {0}" -f $next.Name) -Tone Good
        }
        '3' {
            $d = Get-BbsDerivedStats -State $State -Catalog $Catalog
            if (-not $d.Software.UnlocksPaid) { Write-BbsLine "Your current software tier can't handle paid features well yet." -Tone Warn; return }

            $new = if ($bbs.PricingId -eq $Catalog.Pricing.Free.Id) { $Catalog.Pricing.Paid.Id } else { $Catalog.Pricing.Free.Id }
            $bbs.PricingId = $new
            Write-BbsLine "Pricing updated." -Tone Good
        }
        '4' {
            $opts = $Catalog.Connectivity
            $currentIdx = ($opts | ForEach-Object Id).IndexOf($bbs.ConnectivityId)
            $nextIdx = [math]::Min($opts.Count - 1, $currentIdx + 1)
            if ($nextIdx -eq $currentIdx) { Write-BbsLine "Already max connectivity." -Tone Dim; return }
            $cost = 100.00 + (90.00 * $nextIdx)

            $current = $opts[$currentIdx]
            $next = $opts[$nextIdx]
            Write-BbsLine ("Current: {0}" -f $current.Name) -Tone Dim
            Write-BbsLine ('Next: {0}  (One-time: ${1:N2}, Monthly: ${2:N2})' -f $next.Name, $cost, $next.MonthlyCost) -Tone None
            if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
            $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
            $bbs.ConnectivityId = $opts[$nextIdx].Id
            Write-BbsLine "Connectivity upgraded." -Tone Good
        }
        '5' {
            $opts = $Catalog.Networks
            $currentIdx = ($opts | ForEach-Object Id).IndexOf($bbs.NetworkId)
            $nextIdx = [math]::Min($opts.Count - 1, $currentIdx + 1)
            if ($nextIdx -eq $currentIdx) { Write-BbsLine "Already on the biggest net." -Tone Dim; return }
            $cost = 80.00 + (70.00 * $nextIdx)

            $current = $opts[$currentIdx]
            $next = $opts[$nextIdx]
            Write-BbsLine ("Current: {0}" -f $current.Name) -Tone Dim
            Write-BbsLine ('Next: {0}  (One-time: ${1:N2}, Monthly: ${2:N2})' -f $next.Name, $cost, $next.MonthlyCost) -Tone None
            if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
            $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
            $bbs.NetworkId = $opts[$nextIdx].Id
            Write-BbsLine "Mail networking installed." -Tone Good
        }
        '6' {
            $opts = $Catalog.Doors
            $currentIdx = ($opts | ForEach-Object Id).IndexOf($bbs.DoorsId)
            $nextIdx = [math]::Min($opts.Count - 1, $currentIdx + 1)
            if ($nextIdx -eq $currentIdx) { Write-BbsLine "Already top door pack." -Tone Dim; return }
            $cost = 75.00 + (55.00 * $nextIdx)

            $current = $opts[$currentIdx]
            $next = $opts[$nextIdx]
            Write-BbsLine ("Current: {0}" -f $current.Name) -Tone Dim
            Write-BbsLine ('Next: {0}  (One-time: ${1:N2}, Monthly: ${2:N2})' -f $next.Name, $cost, $next.LicenseMonthly) -Tone None
            if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
            $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
            $bbs.DoorsId = $opts[$nextIdx].Id
            Write-BbsLine "Doors installed. Callers will linger." -Tone Good
        }
        '7' {
            Write-Host ""
            Write-BbsLine "Hardware" -Tone Accent
            Write-BbsLine "1) CPU  2) RAM  3) Disk  X) Back" -Tone None
            $h = Read-BbsChoice -Prompt "Choose" -Options @('1','2','3','X')
            if ($h -eq 'X') { return }

            if ($h -eq '1') {
                $tiers = $Catalog.CpuTiers
                $idx = ($tiers | ForEach-Object Id).IndexOf($bbs.CpuId)
                $nidx = [math]::Min($tiers.Count - 1, $idx + 1)
                if ($nidx -eq $idx) { Write-BbsLine "Already max CPU." -Tone Dim; return }
                $cost = $tiers[$nidx].Cost

                Write-BbsLine ("Current: {0}" -f $tiers[$idx].Name) -Tone Dim
                Write-BbsLine ('Next: {0}  (One-time: ${1:N2})' -f $tiers[$nidx].Name, $cost) -Tone None
                if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
                $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
                $bbs.CpuId = $tiers[$nidx].Id
                Write-BbsLine "CPU upgraded." -Tone Good
            }
            elseif ($h -eq '2') {
                $tiers = $Catalog.RamTiersMB
                $idx = ($tiers | ForEach-Object MB).IndexOf($bbs.RamMB)
                $nidx = [math]::Min($tiers.Count - 1, $idx + 1)
                if ($nidx -eq $idx) { Write-BbsLine "Already max RAM." -Tone Dim; return }
                $cost = $tiers[$nidx].Cost

                Write-BbsLine ("Current: {0}MB" -f $tiers[$idx].MB) -Tone Dim
                Write-BbsLine ('Next: {0}MB  (One-time: ${1:N2})' -f $tiers[$nidx].MB, $cost) -Tone None
                if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
                $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
                $bbs.RamMB = $tiers[$nidx].MB
                Write-BbsLine "RAM expanded." -Tone Good
            }
            elseif ($h -eq '3') {
                $tiers = $Catalog.DiskTiersMB
                $idx = ($tiers | ForEach-Object MB).IndexOf($bbs.DiskMB)
                $nidx = [math]::Min($tiers.Count - 1, $idx + 1)
                if ($nidx -eq $idx) { Write-BbsLine "Already max disk." -Tone Dim; return }
                $cost = $tiers[$nidx].Cost

                Write-BbsLine ("Current: {0}MB" -f $tiers[$idx].MB) -Tone Dim
                Write-BbsLine ('Next: {0}MB  (One-time: ${1:N2})' -f $tiers[$nidx].MB, $cost) -Tone None
                if ($fin.Cash -lt $cost) { Write-BbsLine ('Need ${0:N2} (cash: ${1:N2}).' -f $cost, $fin.Cash) -Tone Warn; return }
                $fin.Cash = [math]::Round($fin.Cash - $cost, 2)
                $bbs.DiskMB = $tiers[$nidx].MB
                Write-BbsLine "Disk upgraded." -Tone Good
            }
        }
        default { }
    }
}

function Start-BbsGame {
    <#
    .SYNOPSIS
    Starts the BBS Tycoon game.

    .DESCRIPTION
    Loads an existing save (unless `-NewGame` is specified) or creates a new one,
    then runs either:
    - Interactive mode (menu-driven loop), when `-SimDays` is 0
    - Scriptable simulation mode, when `-SimDays` is > 0

    In scriptable mode, the game advances `-SimDays` days, saves, prints a short
    summary, and returns.

    .PARAMETER SavePath
    Path to the JSON save file.

    .PARAMETER SimDays
    If greater than 0, advances the simulation for that many days and exits.

    .PARAMETER NewGame
    Forces creating a new game state instead of loading an existing save.

    .PARAMETER NewGameName
    Name to use when creating a new game.

    .EXAMPLE
    Start-BbsGame -SavePath ./saves/save.json

    .EXAMPLE
    Start-BbsGame -SavePath ./saves/sim.json -NewGame -NewGameName 'Test Board' -SimDays 10

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SavePath,
        [Parameter()][int]$SimDays = 0,
        [Parameter()][switch]$NewGame,
        [Parameter()][string]$NewGameName
    )

    Set-BbsConsoleTheme

    $catalog = Get-BbsCatalog

    if ($NewGame) {
        $state = $null
    } else {
        $state = Load-BbsState -SavePath $SavePath
    }

    if (-not $state) {
        Clear-Host
        Write-BbsLine "BBS Tycoon (PowerShell)" -Tone Accent
        Write-BbsLine "" -Tone None
        Write-BbsLine "You are the sysop of a late-80s/90s bulletin board." -Tone None
        Write-BbsLine "One phone line is one node: one caller at a time." -Tone None
        Write-BbsLine "Busy signals are real. Door games build habits. Nightly mail runs spread your name." -Tone None
        Write-BbsLine "Grow callers, pay the phone bill, and keep the board alive." -Tone None
        Write-Host ""

        $name = $NewGameName
        if ([string]::IsNullOrWhiteSpace($name) -and $SimDays -le 0) {
            $name = Read-Host "Name your BBS"
        }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = 'The Rusty Modem' }
        $state = New-BbsState -BbsName $name -Catalog $catalog
        Save-BbsState -State $state -SavePath $SavePath
    }

    if ($SimDays -gt 0) {
        1..$SimDays | ForEach-Object { Step-BbsOneDay -State $state -Catalog $catalog | Out-Null }
        Save-BbsState -State $state -SavePath $SavePath

        $d = Get-BbsDerivedStats -State $state -Catalog $catalog
        Write-BbsLine ("Sim complete: {0} | {1}" -f $state.Bbs.Name, (Format-BbsTime $state.Time)) -Tone Accent
        Write-BbsLine ('Users: {0}/{1}  Cash: ${2:N2}  Last day: ${3:N2}' -f $state.Bbs.Users, $d.UserCap, $state.Finance.Cash, $state.Finance.LastDayNet) -Tone None
        return
    }

    while ($true) {
        Clear-Host
        Show-BbsStatus -State $state -Catalog $catalog

        Write-Host ""
        Write-BbsLine "Main Menu" -Tone Accent
        Write-BbsLine "1) Advance 1 day" -Tone None
        Write-BbsLine "2) Advance 7 days" -Tone None
        Write-BbsLine "3) Upgrades" -Tone None
        Write-BbsLine "4) Save" -Tone None
        Write-BbsLine "Q) Quit" -Tone None

        $c = Read-BbsChoice -Prompt "Choose" -Options @('1','2','3','4','Q') -Default '1'
        switch ($c) {
            '1' {
                Step-BbsOneDay -State $state -Catalog $catalog | Out-Null
                if ($state.Finance.Cash -lt -50) {
                    Write-BbsLine "Your cash is deeply negative. The phone company is unhappy." -Tone Bad
                    Read-Host "Press Enter"
                }
            }
            '2' {
                1..7 | ForEach-Object { Step-BbsOneDay -State $state -Catalog $catalog | Out-Null }
            }
            '3' {
                Show-BbsUpgrades -State $state -Catalog $catalog
                Read-Host "Press Enter"
            }
            '4' {
                Save-BbsState -State $state -SavePath $SavePath
                Write-BbsLine "Saved." -Tone Good
                Start-Sleep -Milliseconds 500
            }
            'Q' {
                Save-BbsState -State $state -SavePath $SavePath
                return
            }
        }
    }
}
