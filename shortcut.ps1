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

    $shortcutObject = $wshShell.CreateShortcut($Shortcut)

    return $shortcutObject.IconLocation
}

function Get-ShortcutTarget {
    <#
    .SYNOPSIS
        Returns the target location of a shortcut.

    .DESCRIPTION
        Returns the target location of the specified shortcut.

    .PARAMETER Shortcut
        The location of the shortcut to read the target location from.

    .OUTPUTS
        string - The target location of the shortcut.

    .EXAMPLE
        Get-ShortcutTarget -Shortcut "C:\Users\UserName\Desktop\MyShortcut.lnk"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Shortcut
    )

    $shortcutObject = $wshShell.CreateShortcut($Shortcut)

    return $shortcutObject.TargetPath
}

function Set-ShortcutTarget {
    <#
    .SYNOPSIS
        Sets the target location of a shortcut.

    .DESCRIPTION
        Sets the target location of the specified shortcut.

    .PARAMETER Shortcut
        The location of the shortcut to set the target location on.

    .PARAMETER Target
        The target location to set on the shortcut.

    .EXAMPLE
        Set-ShortcutTarget -Shortcut "C:\Users\UserName\Desktop\MyShortcut.lnk" -Target "C:\Windows\notepad.exe"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Shortcut,

        [Parameter(Mandatory = $true)]
        [string] $Target
    )

    $shortcutObject = $wshShell.CreateShortcut($Shortcut)
    $shortcutObject.TargetPath = $Target

    if ($PSCmdlet.ShouldProcess($Shortcut, "Set target: '$Target'")) {
        $shortcutObject.Save()
    }
}
