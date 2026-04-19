<#
.SYNOPSIS
Game state model and derived stats for BBS Tycoon.

.DESCRIPTION
Defines functions to create a new game state and to compute derived statistics
(capacity, quality, reach, pricing selection) used by the simulation and UI.

This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Model.ps1')
$state = New-BbsState -BbsName 'The Rusty Modem'
$catalog = Get-BbsCatalog
$derived = Get-BbsDerivedStats -State $state -Catalog $catalog
$derived.UserCap

.OUTPUTS
This script defines functions; it does not output anything when dot-sourced.
#>

Set-StrictMode -Version Latest

function New-BbsState {
    <#
    .SYNOPSIS
    Creates a new default game state.

    .DESCRIPTION
    Creates and returns a `[pscustomobject]` representing the current game state,
    including the current time, BBS configuration, finances, and flags.

    If `-Catalog` is not provided, the function calls `Get-BbsCatalog`.

    .PARAMETER BbsName
    The display name of the BBS.

    .PARAMETER Catalog
    The game catalog returned by `Get-BbsCatalog`. If omitted, the catalog is
    retrieved automatically.

    .EXAMPLE
    $state = New-BbsState -BbsName 'The Rusty Modem'

    .OUTPUTS
    System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BbsName,
        [Parameter()][pscustomobject]$Catalog
    )

    if (-not $Catalog) { $Catalog = Get-BbsCatalog }

    $software = $Catalog.SoftwareTiers[0]
    $cpu = $Catalog.CpuTiers[0]
    $ram = $Catalog.RamTiersMB[0]
    $disk = $Catalog.DiskTiersMB[0]
    $net = $Catalog.Networks | Where-Object Id -eq 'None'
    $conn = $Catalog.Connectivity | Where-Object Id -eq 'POTS'
    $doors = $Catalog.Doors | Where-Object Id -eq 'None'

    [pscustomobject]@{
        Version = 1
        Time = (New-BbsGameTime)

        Bbs = [pscustomobject]@{
            Name = $BbsName
            SoftwareId = $software.Id
            PricingId = $Catalog.Pricing.Free.Id

            PhoneLines = 1
            ConnectivityId = $conn.Id
            NetworkId = $net.Id
            DoorsId = $doors.Id

            CpuId = $cpu.Id
            RamMB = $ram.MB
            DiskMB = $disk.MB

            Users = 40
            Reputation = 0.50
        }

        Finance = [pscustomobject]@{
            Cash = 250.00
            LifetimeProfit = 0.00
            LastDayNet = 0.00
        }

        Flags = [pscustomobject]@{
            HasIntroduced = $false
        }
    }
}

function Get-BbsDerivedStats {
    <#
    .SYNOPSIS
    Computes derived statistics from the current state.

    .DESCRIPTION
    Looks up the selected upgrade tiers from the catalog and calculates
    derived values used by simulation and UI, including:
    - Capacity: `ConcurrentCap` (phone lines) and `UserCap`
    - Composite quality and reach values
    - A simplified `HardwareFactor`

    .PARAMETER State
    The current game state object.

    .PARAMETER Catalog
    The catalog object returned by `Get-BbsCatalog`.

    .EXAMPLE
    $catalog = Get-BbsCatalog
    $state = New-BbsState -BbsName 'Test' -Catalog $catalog
    Get-BbsDerivedStats -State $state -Catalog $catalog | Select-Object UserCap, Reach, Quality

    .OUTPUTS
    System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$State,
        [Parameter(Mandatory)][pscustomobject]$Catalog
    )

    $bbs = $State.Bbs

    $software = $Catalog.SoftwareTiers | Where-Object Id -eq $bbs.SoftwareId
    $cpu = $Catalog.CpuTiers | Where-Object Id -eq $bbs.CpuId
    $ram = $Catalog.RamTiersMB | Where-Object MB -eq $bbs.RamMB
    $disk = $Catalog.DiskTiersMB | Where-Object MB -eq $bbs.DiskMB

    $network = $Catalog.Networks | Where-Object Id -eq $bbs.NetworkId
    $connect = $Catalog.Connectivity | Where-Object Id -eq $bbs.ConnectivityId
    $doors = $Catalog.Doors | Where-Object Id -eq $bbs.DoorsId

    $pricing = if ($bbs.PricingId -eq $Catalog.Pricing.Paid.Id) { $Catalog.Pricing.Paid } else { $Catalog.Pricing.Free }

    # Very simplified capacity model: max concurrent sessions ~ phone lines,
    # and overall user base capped by software tier and hardware quality.
    $hardwareFactor = [math]::Min(1.25, ($cpu.Perf + ($bbs.RamMB / 32.0) + ($bbs.DiskMB / 2000.0)) / 3.0)
    $userCap = [int][math]::Floor($software.MaxUsers * $hardwareFactor)

    [pscustomobject]@{
        Software = $software
        Cpu = $cpu
        Ram = $ram
        Disk = $disk
        Network = $network
        Connectivity = $connect
        Doors = $doors
        Pricing = $pricing

        ConcurrentCap = [int]$bbs.PhoneLines
        UserCap = [int]$userCap

        Quality = [math]::Min(1.0, 0.30 + (0.55 * $software.Quality) + (0.10 * $doors.Fun) + (0.05 * $network.Reach))
        Reach = [math]::Min(0.6, $connect.Attract + $network.Reach)
        HardwareFactor = $hardwareFactor
    }
}
