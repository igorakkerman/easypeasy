function Get-Usage {
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
