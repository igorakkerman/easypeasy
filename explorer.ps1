function Stop-Explorer {
    [CmdletBinding()]
    Param()

    Stop-Process -ProcessName explorer

    <#
    .SYNOPSIS
        Restarts Windows Explorer.

    .DESCRIPTION
        Stops the Windows Explorer process, which (generally) triggers a restart.

    .ALIASES
        sx
    #>

}

New-Alias -Name sx -Value Stop-Explorer
