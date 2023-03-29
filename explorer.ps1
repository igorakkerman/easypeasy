function Stop-Explorer {
    [CmdletBinding()]
    Param()

    Stop-Process -ProcessName explorer
}

New-Alias -Name sx -Value Stop-Explorer
