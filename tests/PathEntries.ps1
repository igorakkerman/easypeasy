# Builders for SystemPathLocation entries, the shape the system-path functions pass around.
# The class lives in the module, so both builders reach into the module scope to construct it.

function New-PathEntries {
    <#
    .SYNOPSIS
        Builds SystemPathLocation entries from a semicolon-separated path, stored form equal to expanded.
    .EXAMPLE
        New-PathEntries 'C:\A;C:\B' -Scope Machine
    #>
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Path,
        [string] $Scope = "User"
    )

    InModuleScope easypeasy -Parameters @{ path = $Path; scope = $Scope } {
        @($path -split ([IO.Path]::PathSeparator) | Where-Object { $_ } | ForEach-Object {
                [SystemPathLocation]::new($scope, $_, $_)
            })
    }
}

function New-PathEntry {
    <#
    .SYNOPSIS
        Builds a single SystemPathLocation entry whose stored form differs from its expanded location.
    .EXAMPLE
        New-PathEntry -ExpandableLocation '%SystemRoot%\System32' -Location 'C:\WINDOWS\System32'
    #>
    param (
        [Parameter(Mandatory)]
        [string] $ExpandableLocation,
        [Parameter(Mandatory)]
        [string] $Location,
        [string] $Scope = "User"
    )

    InModuleScope easypeasy -Parameters @{ expandable = $ExpandableLocation; location = $Location; scope = $Scope } {
        [SystemPathLocation]::new($scope, $expandable, $location)
    }
}

function Get-StoredPath {
    <#
    .SYNOPSIS
        Joins the stored (expandable) form of entries, for asserting what would be persisted.
    .EXAMPLE
        Get-StoredPath $Entries | Should -Be 'C:\A;C:\B'
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline = $false)]
        [AllowEmptyCollection()]
        [object[]] $Entries
    )

    return ($Entries | ForEach-Object { $_.ExpandableLocation }) -join ([IO.Path]::PathSeparator)
}
