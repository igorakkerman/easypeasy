function Get-Timestamp {
    [CmdletBinding()]
    Param()

    Get-Date -Format "yyyy-MM-dd HH.mm.ss"

    <#
    .SYNOPSIS
        Returns the current date and time.

    .DESCRIPTION
        Returns a timestamp of the current instant in the format "yyyy-MM-dd HH.mm.ss".

    .ALIASES
        time
    #>
}

New-Alias -Name time -Value Get-Timestamp
