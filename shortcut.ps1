class Shortcut {

    # Full path of the shortcut's own .lnk file (WScript.Shell FullName).
    [string] $Shortcut

    # Location of the file or folder the shortcut opens: its target.
    [string] $Target

    # Command-line arguments passed to the target.
    [string] $Arguments

    # Location the target runs in, shown as "Start in" in the shortcut properties.
    [string] $StartIn

    # Free-text description, shown as the shortcut's comment / tooltip.
    [string] $Description

    # Icon of the shortcut, or $null when the shortcut carries no icon.
    [ShortcutIcon] $Icon

    # Keyboard shortcut in modifier order, e.g. "Alt+Ctrl+N"; empty when unset.
    [string] $Hotkey

    # Window state the target launches in, shown as "Run" in the shortcut properties.
    [ShortcutWindowStyle] $WindowStyle

    # Whether the target launches elevated, ticked as "Run as administrator" in the advanced properties.
    [bool] $RunAsAdministrator

    <#
    .SYNOPSIS
        The readable fields of a shortcut.
    .DESCRIPTION
        Holds the readable fields of a shortcut: its own location, target location, arguments,
        working directory, description, icon, hotkey and window style.
        The icon is a ShortcutIcon record, or $null when the shortcut carries no icon.
        The write-only RelativePath field is left out, as it cannot be read back.
    .EXAMPLE
        $shortcut = [Shortcut] @{ Shortcut = "C:\Users\me\Desktop\MyApp.lnk"; Target = "C:\Program Files\MyApp\MyApp.exe" }
    #>
}

class ShortcutIcon {

    # Icon source as "file,index", e.g. "C:\Program Files\MyApp\MyApp.exe,3".
    [string] $Value

    # Path of the icon file alone, without index: the Value up to the last comma.
    [string] $Location

    # Zero-based index of the icon within the icon file: the Value after the last comma.
    [int] $Index

    <#
    .SYNOPSIS
        The icon of a shortcut.
    .DESCRIPTION
        Holds a shortcut's icon three ways: Value as the combined "file,index" source, and
        Location and Index as its two parts. All three are always filled.
        A shortcut carrying no icon has no ShortcutIcon at all: its Icon field is $null.
    .EXAMPLE
        $icon = [ShortcutIcon] @{ Value = "C:\Program Files\MyApp\MyApp.exe,3"; Location = "C:\Program Files\MyApp\MyApp.exe"; Index = 3 }
    #>
}

<#
.SYNOPSIS
    The window state a shortcut launches its target in.
.DESCRIPTION
    The states offered as "Run" in the shortcut properties. A shortcut stores no other state:
    any other value is normalized to Normal.
#>
enum ShortcutWindowStyle {
    Normal = 1
    Maximized = 3
    Minimized = 7
}

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

function Get-Shortcut {
    <#
    .SYNOPSIS
        Returns the properties of a shortcut.

    .DESCRIPTION
        Returns an object carrying every readable field of the specified shortcut.
        The write-only RelativePath field is not part of the output, as it cannot be read back.

    .PARAMETER Shortcut
        The location of the shortcut to read.

    .OUTPUTS
        Shortcut record with a Shortcut, Target, Arguments, StartIn, Description, Icon, Hotkey, WindowStyle and RunAsAdministrator property.
        Icon is a ShortcutIcon record with a Value, Location and Index property, or $null when the shortcut carries no icon.
        WindowStyle is a ShortcutWindowStyle: Normal, Maximized or Minimized.

    .EXAMPLE
        Get-Shortcut -Shortcut "C:\Users\me\Desktop\MyShortcut.lnk"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Shortcut
    )

    $obj = $wshShell.CreateShortcut($Shortcut)

    return [Shortcut] @{
        Shortcut           = $obj.FullName
        Target             = $obj.TargetPath
        Arguments          = $obj.Arguments
        StartIn            = $obj.WorkingDirectory
        Description        = $obj.Description
        Icon               = ConvertTo-ShortcutIcon -Value $obj.IconLocation
        Hotkey             = $obj.Hotkey
        WindowStyle        = $obj.WindowStyle
        RunAsAdministrator = Test-RunAsAdministrator -Shortcut $Shortcut
    }
}

function local:ConvertTo-ShortcutIcon {
    <#
    .SYNOPSIS
        Converts a shortcut icon source into a ShortcutIcon record.
    .DESCRIPTION
        Splits an icon source of the form "file,index" into its icon file location and icon index.
        The icon file path may itself contain a comma, so the index is split off at the last one.
        A shortcut carrying no icon reports ',0': a blank location means there is no icon to
        describe, and $null is returned.
    .PARAMETER Value
        The icon source to convert, as reported by WScript.Shell: "file,index".
    .OUTPUTS
        ShortcutIcon record, or $null when the icon source names no icon file.
    .EXAMPLE
        ConvertTo-ShortcutIcon -Value "C:\Program Files\MyApp\MyApp.exe,3"
    #>
    [CmdletBinding()]
    [OutputType([ShortcutIcon])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Value
    )

    $separatorPosition = $Value.LastIndexOf(',')
    $location = $separatorPosition -ge 0 ? $Value.Substring(0, $separatorPosition) : $Value
    $index = $separatorPosition -ge 0 ? $Value.Substring($separatorPosition + 1) : 0

    if (-not $location) {
        return $null
    }

    return [ShortcutIcon] @{
        Value    = $Value
        Location = $location
        Index    = $index
    }
}

function local:Test-RunAsAdministrator {
    <#
    .SYNOPSIS
        Tests whether a shortcut launches its target elevated.
    .DESCRIPTION
        Reads the "Run as administrator" flag straight from the .lnk file: byte 21 (0x15), bit 6 (0x20).
        WScript.Shell does not expose the flag, so the file is read as bytes.
    .PARAMETER Shortcut
        The location of the shortcut to read the flag from.
    .OUTPUTS
        Boolean indicating whether the shortcut launches its target elevated.
    .EXAMPLE
        Test-RunAsAdministrator -Shortcut "C:\Users\me\Desktop\MyApp.lnk"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Shortcut
    )

    $bytes = [System.IO.File]::ReadAllBytes($Shortcut)

    return ($bytes[0x15] -band 0x20) -eq 0x20
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

    $obj = $wshShell.CreateShortcut($Shortcut)
    $obj.TargetPath = $Target

    if ($PSCmdlet.ShouldProcess($Shortcut, "Set target: '$Target'")) {
        $obj.Save()
    }
}
