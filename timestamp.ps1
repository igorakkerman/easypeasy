function Get-Timestamp {
    Get-Date -Format "yyyy-MM-dd HH.mm.ss"
}

New-Alias -Name time -Value Get-Timestamp
