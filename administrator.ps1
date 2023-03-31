function Assert-Administrator {
    [CmdletBinding()]
    param ()

    $identity = [Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if (! $identity.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This operation requires administrator privileges." -ErrorAction Stop
    }
}

