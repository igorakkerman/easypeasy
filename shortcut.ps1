function Set-ShortcutRunAsAdministrator {
    <#
    .SYNOPSIS
        Modifies a shortcut to run as administrator.

    .DESCRIPTION
        Sets the "Run as administrator" flag on the specified shortcut.

    .PARAMETER Shortcut
        The path to the shortcut to set the "Run as administrator" flag on.

    .EXAMPLE
        Set-ShortcutRunAsAdministrator -Shortcut "C:\Users\UserName\Desktop\MyShortcut.lnk"

    .NOTES
        This function is based on the answer at https://stackoverflow.com/a/29002207/2562544.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Shortcut
    )

    $bytes = [System.IO.File]::ReadAllBytes($Shortcut)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON

    if ($PSCmdlet.ShouldProcess($Shortcut, "Set 'Run as administrator' flag")) {
        [System.IO.File]::WriteAllBytes($Shortcut, $bytes)
    }
}

function Get-ShortcutIcon {
    <#
    .SYNOPSIS
        Returns the icon location of a shortcut.

    .DESCRIPTION
        Returns the icon location of the specified shortcut.

    .PARAMETER Shortcut
        The path to the shortcut to read the icon location from.

    .OUTPUTS
        string - The icon location of the shortcut.

    .EXAMPLE
        Get-ShortcutIcon -Shortcut "C:\Users\UserName\Desktop\MyShortcut.lnk"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Shortcut
    )

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcutObject = $wshShell.CreateShortcut($Shortcut)

    return $shortcutObject.IconLocation
}
