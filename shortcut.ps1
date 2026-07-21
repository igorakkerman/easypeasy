function Set-ShortcutRunAsAdministrator {
    <#
    .SYNOPSIS
        Modifies a shortcut to run as administrator.

    .DESCRIPTION
        Sets the "Run as administrator" flag on the specified shortcut.

    .PARAMETER ShortcutLocation
        The path to the shortcut to set the "Run as administrator" flag on.

    .EXAMPLE
        Set-ShortcutRunAsAdministrator -ShortcutLocation "C:\Users\UserName\Desktop\MyShortcut.lnk"

    .NOTES
        This function is based on the answer at https://stackoverflow.com/a/29002207/2562544.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Location")]
        [string] $ShortcutLocation
    )

    $bytes = [System.IO.File]::ReadAllBytes($ShortcutLocation)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON

    if ($PSCmdlet.ShouldProcess($ShortcutLocation, "Set 'Run as administrator' flag")) {
        [System.IO.File]::WriteAllBytes($ShortcutLocation, $bytes)
    }
}

function Get-ShortcutIconLocation {
    <#
    .SYNOPSIS
        Returns the icon location of a shortcut.

    .DESCRIPTION
        Returns the icon location of the specified shortcut.

    .PARAMETER Location
        The path to the shortcut to read the icon location from.

    .OUTPUTS
        string - The icon location of the shortcut.

    .EXAMPLE
        Get-ShortcutIconLocation -Location "C:\Users\UserName\Desktop\MyShortcut.lnk"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($Location)

    return $shortcut.IconLocation
}
