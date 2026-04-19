<#
.SYNOPSIS
Game data catalog for BBS Tycoon.

.DESCRIPTION
Defines the catalog of upgrade tiers and pricing options used by the game
(software tiers, hardware tiers, networks, connectivity, door games, etc.).

This file is intended to be dot-sourced by the entry script.

.EXAMPLE
. (Join-Path $PSScriptRoot 'Data.ps1')
$catalog = Get-BbsCatalog
$catalog.SoftwareTiers | Select-Object Name, MaxUsers

.OUTPUTS
This script defines functions; it does not output anything when dot-sourced.
#>

Set-StrictMode -Version Latest

function Get-BbsCatalog {
    <#
    .SYNOPSIS
    Gets the game catalog describing available tiers and pricing.

    .DESCRIPTION
    Returns a `[pscustomobject]` containing lists of available upgrades and
    related constants used by simulation and UI.

    Values are intentionally simplified and "inspired by" the era rather than
    strictly historical.

    .EXAMPLE
    $catalog = Get-BbsCatalog
    $catalog.CpuTiers | Select-Object Id, Name, Cost

    .EXAMPLE
    (Get-BbsCatalog).Pricing.Paid.MemberMonthlyFee

    .OUTPUTS
    System.Management.Automation.PSCustomObject.
    #>
    [CmdletBinding()]
    param()

    # These are intentionally "inspired by" real era concepts (PCBoard/WWIV-style tiers,
    # 286/386/486/Pentium era CPU steps, phone lines, early ISP shells, FidoNet/RIME-style mail).
    # Keep it gamey rather than perfectly historically priced.

    [pscustomobject]@{
        SoftwareTiers = @(
            [pscustomobject]@{ Id='Shareware'; Name='Shareware BBS Package'; MaxUsers=120; BaseMonthlyCost=0; Quality=0.45; UnlocksPaid=$false },
            [pscustomobject]@{ Id='Registered'; Name='Registered BBS Package'; MaxUsers=350; BaseMonthlyCost=15; Quality=0.60; UnlocksPaid=$true },
            [pscustomobject]@{ Id='Pro'; Name='Professional BBS Suite'; MaxUsers=900; BaseMonthlyCost=55; Quality=0.78; UnlocksPaid=$true },
            [pscustomobject]@{ Id='MultiNode'; Name='Multi-node / LAN-Ready Suite'; MaxUsers=2000; BaseMonthlyCost=120; Quality=0.86; UnlocksPaid=$true }
        )

        CpuTiers = @(
            [pscustomobject]@{ Id='286'; Name='80286'; Cost=0; Perf=0.35 },
            [pscustomobject]@{ Id='386'; Name='80386'; Cost=120; Perf=0.55 },
            [pscustomobject]@{ Id='486'; Name='80486'; Cost=260; Perf=0.75 },
            [pscustomobject]@{ Id='P90'; Name='Pentium 90'; Cost=520; Perf=0.95 },
            [pscustomobject]@{ Id='P200'; Name='Pentium 200'; Cost=900; Perf=1.10 }
        )

        RamTiersMB = @(
            [pscustomobject]@{ MB=2; Cost=0 },
            [pscustomobject]@{ MB=4; Cost=40 },
            [pscustomobject]@{ MB=8; Cost=90 },
            [pscustomobject]@{ MB=16; Cost=200 },
            [pscustomobject]@{ MB=32; Cost=420 }
        )

        DiskTiersMB = @(
            [pscustomobject]@{ MB=40; Cost=0 },
            [pscustomobject]@{ MB=120; Cost=70 },
            [pscustomobject]@{ MB=340; Cost=180 },
            [pscustomobject]@{ MB=850; Cost=420 },
            [pscustomobject]@{ MB=2000; Cost=750 }
        )

        Networks = @(
            [pscustomobject]@{ Id='None'; Name='No Mail Network'; MonthlyCost=0; Reach=0.00 },
            [pscustomobject]@{ Id='RIME'; Name='RIME-style Mail/Net'; MonthlyCost=12; Reach=0.12 },
            [pscustomobject]@{ Id='Fido'; Name='FidoNet-style Echomail'; MonthlyCost=20; Reach=0.22 }
        )

        Connectivity = @(
            [pscustomobject]@{ Id='POTS'; Name='Dial-up Only'; MonthlyCost=0; Attract=0.00 },
            [pscustomobject]@{ Id='Shell'; Name='Shell/ISP Gateway (Telnet-ish)'; MonthlyCost=35; Attract=0.10 },
            [pscustomobject]@{ Id='FullIP'; Name='Full Internet Presence (Telnet + Email)'; MonthlyCost=75; Attract=0.18 }
        )

        Doors = @(
            [pscustomobject]@{ Id='None'; Name='No Door Games'; LicenseMonthly=0; Fun=0.00 },
            [pscustomobject]@{ Id='Classic'; Name='Classic Door Pack (LORD/TradeWars-like)'; LicenseMonthly=10; Fun=0.10 },
            [pscustomobject]@{ Id='Premium'; Name='Premium Door Pack'; LicenseMonthly=25; Fun=0.18 }
        )

        PhoneLine = [pscustomobject]@{ MonthlyCostPerLine = 22 }

        Pricing = [pscustomobject]@{
            Free = [pscustomobject]@{ Id='Free'; Name='Free Board'; MemberMonthlyFee=0; AdsPerDayIncome=0.35; Churn=0.06 }
            Paid = [pscustomobject]@{ Id='Paid'; Name='Paid Membership'; MemberMonthlyFee=4.00; AdsPerDayIncome=0.05; Churn=0.03 }
        }
    }
}
