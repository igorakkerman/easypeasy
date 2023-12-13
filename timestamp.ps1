function Get-Timestamp {
    [CmdletBinding()]
    Param()

    Get-Date -Format "yyyy-MM-dd_HH.mm.ss"

    <#
    .SYNOPSIS
        Returns the current date and time.

    .DESCRIPTION
        Returns a timestamp of the current instant 
        suitable for filenames and logs with a precision 
        at least to the second.
        Note that the format may change in the future
        and should not be relied upon.

    .ALIASES
        time
    #>
}

New-Alias -Name time -Value Get-Timestamp
