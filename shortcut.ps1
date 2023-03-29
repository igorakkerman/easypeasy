function Set-ShortcutRunAsAdministrator {

    <#
    .SYNOPSIS
        Modifies a shortcut to run as administrator.

    .DESCRIPTION
        Sets the "Run as administrator" flag on the specified shortcut.

    .PARAMETER ShortcutPath
        The path to the shortcut to set the "Run as administrator" flag on.

    .EXAMPLE
        Set-ShortcutRunAsAdministrator -ShortcutPath "C:\Users\UserName\Desktop\MyShortcut.lnk"

    .NOTES
        This function is based on the answer at https://stackoverflow.com/a/29002207/2562544.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Path")]
        [string] $ShortcutPath
    )

    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
}
