<#
.SYNOPSIS
Simulation and random events for BBS Tycoon.

.DESCRIPTION
Defines the day-to-day simulation step (income/expenses, churn/attract, time
advance) and a small weighted random event system that adds flavor and minor
mechanical changes.

This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Simulation.ps1')
$catalog = Get-BbsCatalog
$state = New-BbsState -BbsName 'Test' -Catalog $catalog
Step-BbsOneDay -State $state -Catalog $catalog | Out-Null

.OUTPUTS
This script defines functions; it does not output anything when dot-sourced.
#>

Set-StrictMode -Version Latest

function Get-BbsWeightedChoiceIndex {
    <#
    .SYNOPSIS
    Picks an index from a list of weights.

    .DESCRIPTION
    Interprets `-Weights` as relative weights for each index and uses `Get-Random`
    to choose an index proportionally. Non-positive weights are treated as zero.
    Returns -1 when the total weight is <= 0.

    .PARAMETER Weights
    A list of weights corresponding to each choice.

    .EXAMPLE
    Get-BbsWeightedChoiceIndex -Weights @(0.7, 0.2, 0.1)

    .OUTPUTS
    System.Int32.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][double[]]$Weights
    )

    $total = 0.0
    foreach ($w in $Weights) {
        if ($w -gt 0) { $total += $w }
    }
    if ($total -le 0) { return -1 }

    $r = Get-Random -Minimum 0.0 -Maximum $total
    $acc = 0.0
    for ($i = 0; $i -lt $Weights.Count; $i++) {
        $w = $Weights[$i]
        if ($w -le 0) { continue }
        $acc += $w
        if ($r -lt $acc) { return $i }
    }

    return ($Weights.Count - 1)
}

function Invoke-BbsRandomEvent {
    <#
    .SYNOPSIS
    Applies a weighted random flavor event to the current state.

    .DESCRIPTION
    Chooses a weighted event based on the current configuration and conditions
    (busy rate, installed doors, networks, connectivity, etc.) and mutates the
    state accordingly.

    The function ensures the state has a `_LastEvent` property (creating it if
    missing) and sets it to the most recent event description or `$null`.

    .PARAMETER State
    The current game state to mutate.

    .PARAMETER Catalog
    The game catalog returned by `Get-BbsCatalog`.

    .PARAMETER Derived
    The derived stats object returned by `Get-BbsDerivedStats`.

    .PARAMETER BusyRate
    Approximate fraction of call attempts that hit a busy signal (0.0 to 1.0).

    .EXAMPLE
    $derived = Get-BbsDerivedStats -State $state -Catalog $catalog
    Invoke-BbsRandomEvent -State $state -Catalog $catalog -Derived $derived -BusyRate 0.2

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$State,
        [Parameter(Mandatory)][pscustomobject]$Catalog,
        [Parameter(Mandatory)][pscustomobject]$Derived,
        [Parameter(Mandatory)][double]$BusyRate
    )

    if (-not ($State.PSObject.Properties.Name -contains '_LastEvent')) {
        $State | Add-Member -NotePropertyName '_LastEvent' -NotePropertyValue $null
    }

    $bbs = $State.Bbs
    $fin = $State.Finance

    # 0) No event is common; the rest are weighted and conditional.
    $events = New-Object System.Collections.Generic.List[object]

    $events.Add([pscustomobject]@{
        Weight = 0.78
        Apply = { param($s,$c,$d,$b) $s._LastEvent = $null }
    })

    # --- Always-available texture events ---
    $events.Add([pscustomobject]@{
        Weight = 0.10
        Apply = {
            param($s,$c,$d,$b)
            $s.Finance.Cash = [math]::Round($s.Finance.Cash + (3.50 + (0.01 * $s.Bbs.Users)), 2)
            $s.Bbs.Reputation = [math]::Min(1.0, $s.Bbs.Reputation + 0.01)
            $s._LastEvent = 'A grateful caller mails in a donation with a handwritten note.'
        }
    })

    $events.Add([pscustomobject]@{
        Weight = (0.06 + (0.10 * [math]::Min(0.5, $BusyRate)))
        Apply = {
            param($s,$c,$d,$b)
            $s.Finance.Cash = [math]::Round($s.Finance.Cash - 1.50, 2)
            $s.Bbs.Reputation = [math]::Max(0.0, $s.Bbs.Reputation - (0.01 + (0.02 * [math]::Min(0.6, $b))))
            $s._LastEvent = 'Line noise, retries, and busy signals frustrate callers today.'
        }
    })

    $events.Add([pscustomobject]@{
        Weight = 0.05
        Apply = {
            param($s,$c,$d,$b)
            $s.Bbs.Reputation = [math]::Min(1.0, $s.Bbs.Reputation + 0.02)
            $s._LastEvent = 'A new ANSI artist draws a splash screen; the board feels alive.'
        }
    })

    $events.Add([pscustomobject]@{
        Weight = 0.03
        Apply = {
            param($s,$c,$d,$b)
            $delta = -1 * (2.00 + (0.005 * $s.Bbs.Users))
            $s.Finance.Cash = [math]::Round($s.Finance.Cash + $delta, 2)
            $s._LastEvent = 'A surprise long-distance charge shows up on the phone bill.'
        }
    })

    # --- Door-game culture ---
    if ($Derived.Doors.Id -ne 'None') {
        $events.Add([pscustomobject]@{
            Weight = 0.05
            Apply = {
                param($s,$c,$d,$b)
                $s.Bbs.Reputation = [math]::Min(1.0, $s.Bbs.Reputation + 0.015)
                $s._LastEvent = 'Door-game league night: callers log in just to take their turns.'
            }
        })

        $events.Add([pscustomobject]@{
            Weight = 0.03
            Apply = {
                param($s,$c,$d,$b)
                $fix = 2.25 + (0.10 * ($d.Doors.Fun * 100))
                $s.Finance.Cash = [math]::Round($s.Finance.Cash - $fix, 2)
                $s.Bbs.Reputation = [math]::Max(0.0, $s.Bbs.Reputation - 0.01)
                $s._LastEvent = 'A door game database corrupts; you patch it after midnight.'
            }
        })
    }

    # --- Mail networks / echomail drama ---
    if ($Derived.Network.Id -ne 'None') {
        $events.Add([pscustomobject]@{
            Weight = 0.05
            Apply = {
                param($s,$c,$d,$b)
                # Nightly mail runs cost time/phone, but expand the world.
                $mailCost = 0.90 + (0.15 * $d.Network.Reach * 10)
                $s.Finance.Cash = [math]::Round($s.Finance.Cash - $mailCost, 2)
                $s.Bbs.Reputation = [math]::Min(1.0, $s.Bbs.Reputation + 0.01)
                $s._LastEvent = 'Nightly mail run completes: fresh echoes land in your message bases.'
            }
        })

        $events.Add([pscustomobject]@{
            Weight = 0.03
            Apply = {
                param($s,$c,$d,$b)
                $s.Bbs.Reputation = [math]::Max(0.0, $s.Bbs.Reputation - 0.02)
                $s._LastEvent = 'An echomail flamewar spills over; moderation takes your evening.'
            }
        })

        $events.Add([pscustomobject]@{
            Weight = 0.02
            Apply = {
                param($s,$c,$d,$b)
                $delta = -1 * (3.50 + (0.01 * $s.Bbs.Users))
                $s.Finance.Cash = [math]::Round($s.Finance.Cash + $delta, 2)
                $s.Bbs.Reputation = [math]::Max(0.0, $s.Bbs.Reputation - 0.01)
                $s._LastEvent = 'Net trouble: a missed call window leaves you out of sync for a day.'
            }
        })
    }

    # --- Internet transition vibes ---
    if ($Derived.Connectivity.Id -ne 'POTS') {
        $events.Add([pscustomobject]@{
            Weight = 0.04
            Apply = {
                param($s,$c,$d,$b)
                $boost = [int][math]::Max(1, [math]::Floor(2 + (0.02 * $s.Bbs.Users)))
                $s.Bbs.Users = [math]::Min((Get-BbsDerivedStats -State $s -Catalog $c).UserCap, $s.Bbs.Users + $boost)
                $s._LastEvent = 'A wave of out-of-town callers finds your gateway and sticks around.'
            }
        })
    }

    # --- Multinode prestige ---
    if ($bbs.PhoneLines -ge 2) {
        $events.Add([pscustomobject]@{
            Weight = 0.03
            Apply = {
                param($s,$c,$d,$b)
                $s.Bbs.Reputation = [math]::Min(1.0, $s.Bbs.Reputation + 0.01)
                $s._LastEvent = 'Node 2 chatter becomes a nightly ritual; your board feels busy (in a good way).'
            }
        })
    }

    # --- The ever-present risk of unwanted attention (kept non-glamorized) ---
    $events.Add([pscustomobject]@{
        Weight = 0.015
        Apply = {
            param($s,$c,$d,$b)
            $s.Bbs.Reputation = [math]::Max(0.0, $s.Bbs.Reputation - 0.03)
            $s.Finance.Cash = [math]::Round($s.Finance.Cash - 2.75, 2)
            $s._LastEvent = 'You tighten file-area rules to avoid the wrong kind of attention. Some users grumble.'
        }
    })

    $weights = @($events | ForEach-Object { [double]$_.Weight })
    $idx = Get-BbsWeightedChoiceIndex -Weights $weights
    if ($idx -lt 0) {
        $State._LastEvent = $null
        return
    }

    & $events[$idx].Apply $State $Catalog $Derived $BusyRate
}

function Step-BbsOneDay {
    <#
    .SYNOPSIS
    Advances the simulation by one in-game day.

    .DESCRIPTION
    Updates the state in place for one simulated day:
    - Computes busy rate and demand (attract/churn)
    - Updates user count (bounded by capacity)
    - Calculates daily income and expenses
    - Applies a random event
    - Updates cash and reputation
    - Advances time by 24 hours

    .PARAMETER State
    The current game state to mutate.

    .PARAMETER Catalog
    The game catalog returned by `Get-BbsCatalog`.

    .EXAMPLE
    $state = Step-BbsOneDay -State $state -Catalog $catalog

    .OUTPUTS
    System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$State,
        [Parameter(Mandatory)][pscustomobject]$Catalog
    )

    $derived = Get-BbsDerivedStats -State $State -Catalog $Catalog
    $bbs = $State.Bbs
    $fin = $State.Finance

    # Phone-line contention: approximate "peak hour" call attempts.
    # More reach/quality/doors -> more attempts; more lines -> fewer busy signals.
    $attemptRate = 0.030 + (0.060 * $derived.Reach) + (0.060 * $derived.Quality) + (0.030 * $derived.Doors.Fun)
    $callAttempts = [math]::Max(1.0, $bbs.Users * $attemptRate)
    $busyRate = 0.0
    if ($callAttempts -gt 0 -and $derived.ConcurrentCap -gt 0) {
        $busyRate = [math]::Max(0.0, ($callAttempts - $derived.ConcurrentCap) / $callAttempts)
    }
    $busyRate = [math]::Min(0.65, $busyRate)

    # Demand: depends on reach, reputation, and fun/quality.
    $attract = 0.03 + (0.06 * $derived.Reach) + (0.05 * $derived.Quality) + (0.04 * $bbs.Reputation)
    $attract -= (0.05 * $busyRate)
    $attract = [math]::Min(0.22, $attract)

    # Churn: pricing-driven plus slight penalty if near capacity.
    $capacityPressure = 0.0
    if ($bbs.Users -gt 0 -and $derived.UserCap -gt 0) {
        $capacityPressure = [math]::Max(0.0, ($bbs.Users / $derived.UserCap) - 0.85)
    }

    $churn = $derived.Pricing.Churn + (0.05 * $capacityPressure)
    $churn += (0.07 * $busyRate)
    $churn = [math]::Min(0.25, $churn)

    $newUsers = [int][math]::Floor($bbs.Users * $attract)
    $lostUsers = [int][math]::Floor($bbs.Users * $churn)

    $bbs.Users = [math]::Max(0, $bbs.Users + $newUsers - $lostUsers)
    if ($bbs.Users -gt $derived.UserCap) { $bbs.Users = $derived.UserCap }

    # Income model (daily): ads for free boards; membership fees accrue daily for paid.
    $memberDaily = 0.0
    if ($derived.Pricing.Id -eq $Catalog.Pricing.Paid.Id) {
        $memberDaily = ($derived.Pricing.MemberMonthlyFee / 30.0) * $bbs.Users
    }
    $adsDaily = $derived.Pricing.AdsPerDayIncome * [math]::Max(5, [math]::Sqrt($bbs.Users))

    # Small “usage” income from doors/network traffic (tips/donations/paid downloads)
    # Networks add "reach" beyond local callers, which tends to increase light monetization.
    $usageDaily = 0.02 * $bbs.Users * (0.6 + $derived.Quality + (0.40 * $derived.Network.Reach) + (0.30 * $derived.Connectivity.Attract) + (0.25 * $derived.Doors.Fun))

    $income = $memberDaily + $adsDaily + $usageDaily

    # Expenses (daily): phone lines, connectivity, network, software monthly, doors license monthly.
    $phoneDaily = ($Catalog.PhoneLine.MonthlyCostPerLine / 30.0) * $bbs.PhoneLines
    $connDaily = ($derived.Connectivity.MonthlyCost / 30.0)
    $netDaily = ($derived.Network.MonthlyCost / 30.0)
    $softDaily = ($derived.Software.BaseMonthlyCost / 30.0)
    $doorsDaily = ($derived.Doors.LicenseMonthly / 30.0)

    # Hardware upkeep increases with disk size + CPU tier a bit.
    $hwDaily = (0.15 + (0.10 * $derived.HardwareFactor) + (0.05 * ($bbs.DiskMB / 2000.0)))

    $expenses = $phoneDaily + $connDaily + $netDaily + $softDaily + $doorsDaily + $hwDaily

    # Random event (lore-heavy, still lightweight mechanics)
    $preCash = $fin.Cash
    Invoke-BbsRandomEvent -State $State -Catalog $Catalog -Derived $derived -BusyRate $busyRate
    $eventNet = ($fin.Cash - $preCash)

    $net = ($income - $expenses) + $eventNet

    $fin.Cash = [math]::Round($fin.Cash + $net, 2)
    $fin.LifetimeProfit = [math]::Round($fin.LifetimeProfit + $net, 2)
    $fin.LastDayNet = [math]::Round($net, 2)

    # Reputation slowly trends toward quality.
    $bbs.Reputation = [math]::Max(0.0, [math]::Min(1.0, $bbs.Reputation + (0.02 * ($derived.Quality - $bbs.Reputation))))

    # Advance clock by 24h.
    Advance-BbsTime -Time $State.Time -Hours 24 | Out-Null

    return $State
}
