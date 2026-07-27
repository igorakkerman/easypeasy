function Stop-Explorer {
    <#
    .SYNOPSIS
        Restarts Windows Explorer.

    .DESCRIPTION
        Stops the Windows Explorer process, which (generally) triggers a restart.
        An Explorer that is not running is left alone, since it is already stopped.

    .NOTES
        Alias: sx

    .EXAMPLE
        Stop-Explorer
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if ($PSCmdlet.ShouldProcess("Windows Explorer", "Stop all instances")) {
        # nothing to stop is the state asked for, not a failure
        Stop-Process -ProcessName explorer -ErrorAction SilentlyContinue
    }
}

New-Alias -Name sx -Value Stop-Explorer -ErrorAction SilentlyContinue | Out-Null
