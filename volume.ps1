function Get-Usage {
    <#
    .SYNOPSIS
        Returns the disk usage of the child items of a folder.

    .DESCRIPTION
        Returns the disk usage of each child item of the specified folder,
        sorted by size in descending order.

    .PARAMETER Location
        The folder whose child items to measure. Default: the current location.

    .EXAMPLE
        Get-Usage

    .EXAMPLE
        Get-Usage -Location "C:\Program Files"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [object] $Location = "$(Get-Location)"
    )

    Get-ChildItem $Location 
    | ForEach-Object { $f = $_; Get-ChildItem -Recurse $_.FullName 
        | Measure-Object -Property length -Sum 
        | Select-Object @{Name = "Name"; Expression = { $f } }, @{Name = "Sum (MB)"; Expression = { "{0:N3}" -f ($_.sum / 1MB) } }, Sum 
    } 
    | Sort-Object Sum -Descending 
    | Format-Table -Property Name, "Sum (MB)", Sum -AutoSize
}

New-Alias du Get-Usage -ErrorAction SilentlyContinue | Out-Null
