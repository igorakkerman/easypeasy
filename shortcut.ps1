function Set-ShortcutRunAsAdministrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ShortcutPath
    )

    # https://stackoverflow.com/a/29002207/2562544
    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
}
