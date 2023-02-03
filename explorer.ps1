function Stop-Explorer {
    Stop-Process -ProcessName explorer
}

New-Alias -Name sx -Value Stop-Explorer
