class Shortcut {

    # Full path of the shortcut's own .lnk file (WScript.Shell FullName).
    [string] $Location

    # Location of the file or folder the shortcut opens: its target.
    [string] $Target

    # Command-line arguments passed to the target.
    [string] $Arguments

    # Location the target runs in, shown as "Start in" in the shortcut properties.
    [string] $RunLocation

    # Free-text description, shown as the shortcut's comment / tooltip.
    [string] $Description

    # Icon of the shortcut, or $null when the shortcut carries no icon.
    [ShortcutIcon] $Icon

    # Keyboard shortcut in modifier order, e.g. "Alt+Ctrl+N"; empty when unset.
    [string] $Hotkey

    # Window state the target launches in, shown as "Run" in the shortcut properties.
    [ShortcutWindowStyle] $WindowStyle

    # Whether the target launches elevated, ticked as "Run as administrator" in the advanced properties.
    [bool] $Elevated

    <#
    .SYNOPSIS
        The readable fields of a shortcut.
    .DESCRIPTION
        Holds the readable fields of a shortcut: its own location, target location, arguments,
        working directory, description, icon, hotkey and window style.
        The icon is a ShortcutIcon record, or $null when the shortcut carries no icon.
        The write-only RelativePath field is left out, as it cannot be read back.
    .EXAMPLE
        $shortcut = [Shortcut] @{ Location = "C:\Users\me\Desktop\MyApp.lnk"; Target = "C:\Program Files\MyApp\MyApp.exe" }
    #>
}

class ShortcutIcon {

    # Path of the icon file, e.g. "C:\Program Files\MyApp\MyApp.exe". May itself contain a comma.
    [string] $Location

    # Zero-based index of the icon within the icon file.
    [int] $Index

    # The icon as the combined "file,index" source WScript.Shell stores.
    [string] ToString() {
        return "$($this.Location),$($this.Index)"
    }

    <#
    .SYNOPSIS
        The icon of a shortcut.
    .DESCRIPTION
        Holds a shortcut's icon as its two parts, the icon file location and the index within it.
        ToString() combines them back into the "file,index" source a shortcut stores.
        A shortcut carrying no icon has no ShortcutIcon at all: its Icon field is $null.
    .EXAMPLE
        $icon = [ShortcutIcon] @{ Location = "C:\Program Files\MyApp\MyApp.exe"; Index = 3 }
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

function Get-Shortcut {
    <#
    .SYNOPSIS
        Returns the properties of a shortcut.

    .DESCRIPTION
        Returns an object carrying every readable field of the specified shortcut.
        The write-only RelativePath field is not part of the output, as it cannot be read back.

    .PARAMETER Location
        The location of the shortcut to read.

    .OUTPUTS
        Shortcut record with a Location, Target, Arguments, RunLocation, Description, Icon, Hotkey, WindowStyle and Elevated property.
        Icon is a ShortcutIcon record with a Location and Index property, or $null when the shortcut carries no icon.
        WindowStyle is a ShortcutWindowStyle: Normal, Maximized or Minimized.

    .EXAMPLE
        Get-Shortcut -Location "C:\Users\me\Desktop\MyShortcut.lnk"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $obj = $wshShell.CreateShortcut($Location)

    return [Shortcut] @{
        Location           = $obj.FullName
        Target             = $obj.TargetPath
        Arguments          = $obj.Arguments
        RunLocation        = $obj.WorkingDirectory
        Description        = $obj.Description
        Icon               = ConvertTo-ShortcutIcon -Value $obj.IconLocation
        Hotkey             = $obj.Hotkey
        WindowStyle        = $obj.WindowStyle
        Elevated           = Test-ShortcutElevated -Location $Location
    }
}

function New-ShortcutIcon {
    <#
    .SYNOPSIS
        Creates a shortcut icon.

    .DESCRIPTION
        Creates the ShortcutIcon record that New-Shortcut and Set-Shortcut take as their -Icon.
        Give the icon file on its own with -Location, optionally picking the icon within it with -Index,
        or give the combined source with -Value.

    .PARAMETER Location
        The path of the icon file. The icon file may itself contain a comma.

    .PARAMETER Index
        The index of the icon within the icon file. Default: 0.

    .PARAMETER Value
        The combined icon source in the form "file,index", e.g. "C:\Program Files\MyApp\MyApp.exe,3".
        An icon file on its own is rejected here; pass it as -Location instead.

    .OUTPUTS
        ShortcutIcon record with a Location and Index property, combined back by ToString().

    .EXAMPLE
        New-ShortcutIcon "C:\Program Files\MyApp\MyApp.exe,3"

    .EXAMPLE
        New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe"

    .EXAMPLE
        New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3
    #>
    [CmdletBinding(DefaultParameterSetName = "Value")]
    [OutputType([ShortcutIcon])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Value")]
        [string] $Value,

        [Parameter(Mandatory = $true, ParameterSetName = "Location")]
        [string] $Location,

        [Parameter(Mandatory = $false, ParameterSetName = "Location")]
        [int] $Index = 0
    )

    if ($PSCmdlet.ParameterSetName -eq "Location") {
        if (-not $Location) {
            Write-Error "Icon file is required: -Location." `
                -ErrorId "BlankShortcutIconLocation" `
                -Category InvalidArgument `
                -TargetObject $Location `
                -ErrorAction Stop
        }

        return [ShortcutIcon] @{
            Location = $Location
            Index    = $Index
        }
    }

    if ($Value -notmatch ',\d+$') {
        Write-Error "Icon source must be an icon file and an index, as 'file,index'. Pass an icon file on its own as -Location. value: '$Value'" `
            -ErrorId "InvalidShortcutIconValue" `
            -Category InvalidArgument `
            -TargetObject $Value `
            -ErrorAction Stop
    }

    # the icon file may contain a comma, so the index is split off at the last one
    $icon = ConvertTo-ShortcutIcon -Value $Value

    if (-not $icon) {
        Write-Error "Icon source names no icon file. value: '$Value'" `
            -ErrorId "BlankShortcutIconLocation" `
            -Category InvalidArgument `
            -TargetObject $Value `
            -ErrorAction Stop
    }

    return $icon
}

function New-Shortcut {
    <#
    .SYNOPSIS
        Creates a shortcut.

    .DESCRIPTION
        Creates a shortcut at the specified location, pointing at the specified target.
        Only the shortcut location and its target are mandatory; every other field is optional
        and falls back to a default: the target's folder as run location, no icon, no hotkey,
        a normal window and an unelevated target.
        An existing shortcut is left untouched and a terminating error is reported, unless -Force is given.

    .PARAMETER Location
        The location of the shortcut to create, including its .lnk extension.

    .PARAMETER Target
        The location of the file or folder the shortcut opens.

    .PARAMETER Arguments
        The command-line arguments to pass to the target.

    .PARAMETER RunLocation
        The location the target runs in, shown as "Start in" in the shortcut properties.
        Default: the folder of the target.

    .PARAMETER Description
        The free-text description of the shortcut, shown as its comment / tooltip.

    .PARAMETER Icon
        The icon of the shortcut, as a ShortcutIcon record built by New-ShortcutIcon or read by Get-Shortcut.
        Default: no icon.

    .PARAMETER Hotkey
        The keyboard shortcut that opens the shortcut, e.g. "Ctrl+Alt+N".

    .PARAMETER WindowStyle
        The window state the target launches in: Normal, Maximized or Minimized. Default: Normal.

    .PARAMETER Elevated
        Launch the target elevated, ticked as "Run as administrator" in the advanced properties.
        Alias: Administrator.

    .PARAMETER Force
        Completely overwrite the shortcut if it already exists. Omitted optional fields reset to their documented defaults.
        Without -Force, a terminating error is reported when the shortcut exists.

    .OUTPUTS
        Shortcut record describing the created shortcut, as read by Get-Shortcut. Nothing under -WhatIf.

    .EXAMPLE
        New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe"

    .EXAMPLE
        New-Shortcut -Location "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" `
            -Arguments "--profile Default" -Description "My favourite app" `
            -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3) `
            -Hotkey "Ctrl+Alt+M" -WindowStyle Maximized -Elevated

    .NOTES
        Alias: Administrator for -Elevated.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Shortcut])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Location,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Target,

        [Parameter(Mandatory = $false)]
        [string] $Arguments,

        [Parameter(Mandatory = $false)]
        [string] $RunLocation,

        [Parameter(Mandatory = $false)]
        [string] $Description,

        [Parameter(Mandatory = $false)]
        [ShortcutIcon] $Icon,

        [Parameter(Mandatory = $false)]
        [string] $Hotkey,

        [Parameter(Mandatory = $false)]
        [ShortcutWindowStyle] $WindowStyle = [ShortcutWindowStyle]::Normal,

        [Parameter(Mandatory = $false)]
        [Alias("Administrator")]
        [switch] $Elevated,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    if (-not $Force -and (Test-Path -LiteralPath $Location)) {
        Write-Error "Shortcut already exists, use -Force to overwrite. location: '$Location'" `
            -ErrorId "ShortcutAlreadyExists" `
            -Category ResourceExists `
            -TargetObject $Location `
            -ErrorAction Stop
    }

    $shortcutFolder = Split-Path -Parent $Location
    if ($shortcutFolder -and -not (Test-Path -LiteralPath $shortcutFolder)) {
        Write-Error "Shortcut folder not found: '$shortcutFolder'" `
            -ErrorId "ShortcutFolderNotFound" `
            -Category ObjectNotFound `
            -TargetObject $shortcutFolder
        return
    }

    # every field is written, so an overwritten shortcut keeps nothing of its former self
    if ($PSCmdlet.ShouldProcess($Location, "Create shortcut")) {
        $obj = $wshShell.CreateShortcut($Location)
        $obj.TargetPath = $Target
        $obj.Arguments = $Arguments
        $obj.WorkingDirectory = $PSBoundParameters.ContainsKey("RunLocation") ? $RunLocation : (Split-Path -Parent $Target)
        $obj.Description = $Description
        # a shortcut carrying no icon stores ',0'; IconLocation rejects an empty string or $null
        $obj.IconLocation = $Icon ? $Icon.ToString() : ",0"
        $obj.Hotkey = $Hotkey
        $obj.WindowStyle = [int] $WindowStyle
        $obj.Save()

        Set-ShortcutElevated -Location $Location -Elevated $Elevated.IsPresent

        return Get-Shortcut -Location $Location
    }
}

function Set-Shortcut {
    <#
    .SYNOPSIS
        Sets the fields of a shortcut.

    .DESCRIPTION
        Sets any combination of the fields of an existing shortcut. Fields not passed are left as they are.
        Passing $null or an empty string clears a field, e.g. -Arguments $null, -Description '' or -Icon $null.
        At least one field is required. If the shortcut does not exist, an error is reported.

    .PARAMETER Location
        The location of the shortcut to set the fields on.

    .PARAMETER Target
        The location of the file or folder the shortcut opens.

    .PARAMETER Arguments
        The command-line arguments to pass to the target.

    .PARAMETER RunLocation
        The location the target runs in, shown as "Start in" in the shortcut properties.

    .PARAMETER Description
        The free-text description of the shortcut, shown as its comment / tooltip.

    .PARAMETER Icon
        The icon of the shortcut, as a ShortcutIcon record built by New-ShortcutIcon or read by Get-Shortcut.
        Pass $null to clear the icon.

    .PARAMETER Hotkey
        The keyboard shortcut that opens the shortcut, e.g. "Ctrl+Alt+N".

    .PARAMETER WindowStyle
        The window state the target launches in: Normal, Maximized or Minimized.

    .PARAMETER Elevated
        Launch the target elevated, ticked as "Run as administrator" in the advanced properties.
        Pass -Elevated:$false to launch it unelevated. Left out, the flag is not touched. Alias: Administrator.

    .PARAMETER PassThru
        Return the shortcut after setting its fields. Without it, nothing is returned.

    .OUTPUTS
        Shortcut record describing the shortcut, as read by Get-Shortcut, when -PassThru is given.

    .EXAMPLE
        Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe"

    .EXAMPLE
        Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -WindowStyle Maximized -Elevated

    .EXAMPLE
        Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Arguments $null -Icon $null

    .EXAMPLE
        Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Icon (New-ShortcutIcon "C:\Program Files\MyApp\MyApp.exe,3")

    .NOTES
        Alias: Administrator for -Elevated.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Shortcut])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [string] $Target,

        [Parameter(Mandatory = $false)]
        [string] $Arguments,

        [Parameter(Mandatory = $false)]
        [string] $RunLocation,

        [Parameter(Mandatory = $false)]
        [string] $Description,

        [Parameter(Mandatory = $false)]
        [ShortcutIcon] $Icon,

        [Parameter(Mandatory = $false)]
        [string] $Hotkey,

        [Parameter(Mandatory = $false)]
        [ShortcutWindowStyle] $WindowStyle,

        [Parameter(Mandatory = $false)]
        [Alias("Administrator")]
        [switch] $Elevated,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    # the elevation flag is patched into the file bytes, so it is not one of the WScript.Shell fields
    $paramNames = "Target", "Arguments", "RunLocation", "Description", "Icon", "Hotkey", "WindowStyle"

    $setsField = [bool] ($paramNames | Where-Object { $PSBoundParameters.ContainsKey($_) })

    if (-not $setsField -and -not $PSBoundParameters.ContainsKey("Elevated")) {
        Write-Error "At least one shortcut field is required: -$($paramNames -join ', -'), -Elevated." -ErrorAction Stop
    }

    if (-not (Test-Path -LiteralPath $Location -PathType Leaf)) {
        Write-Error "Shortcut not found: '$Location'" `
            -ErrorId "ShortcutNotFound" `
            -Category ObjectNotFound `
            -TargetObject $Location
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Set shortcut fields")) {
        # setting the elevation flag alone touches no field WScript.Shell writes
        if ($setsField) {
            $obj = $wshShell.CreateShortcut($Location)

            if ($PSBoundParameters.ContainsKey("Target")) { $obj.TargetPath = $Target }
            if ($PSBoundParameters.ContainsKey("Arguments")) { $obj.Arguments = $Arguments }
            if ($PSBoundParameters.ContainsKey("RunLocation")) { $obj.WorkingDirectory = $RunLocation }
            if ($PSBoundParameters.ContainsKey("Description")) { $obj.Description = $Description }
            # a shortcut carrying no icon stores ',0'; IconLocation rejects an empty string or $null
            if ($PSBoundParameters.ContainsKey("Icon")) { $obj.IconLocation = $Icon ? $Icon.ToString() : ",0" }
            if ($PSBoundParameters.ContainsKey("Hotkey")) { $obj.Hotkey = $Hotkey }
            if ($PSBoundParameters.ContainsKey("WindowStyle")) { $obj.WindowStyle = [int] $WindowStyle }

            $obj.Save()
        }

        if ($PSBoundParameters.ContainsKey("Elevated")) {
            Set-ShortcutElevated -Location $Location -Elevated $Elevated.IsPresent
        }
    }

    if ($PassThru) {
        return Get-Shortcut -Location $Location
    }
}

function local:Set-ShortcutElevated {
    <#
    .SYNOPSIS
        Sets or clears the "Run as administrator" flag on a shortcut.
    .DESCRIPTION
        Writes the flag straight into the .lnk file: byte 21 (0x15), bit 6 (0x20).
        WScript.Shell does not expose the flag, so the file is written as bytes.
        A file already carrying the requested state is left untouched.
    .PARAMETER Location
        The location of the shortcut to write the flag to.
    .PARAMETER Elevated
        Whether the shortcut launches its target elevated.
    .EXAMPLE
        Set-ShortcutElevated -Location "C:\Users\me\Desktop\MyApp.lnk" -Elevated $true
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [bool] $Elevated
    )

    $bytes = [System.IO.File]::ReadAllBytes($Location)
    $flags = $Elevated ? ($bytes[0x15] -bor 0x20) : ($bytes[0x15] -band 0xDF)

    if ($flags -eq $bytes[0x15]) {
        return
    }

    $bytes[0x15] = $flags
    [System.IO.File]::WriteAllBytes($Location, $bytes)
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
        Location = $location
        Index    = $index
    }
}

function local:Test-ShortcutElevated {
    <#
    .SYNOPSIS
        Tests whether a shortcut launches its target elevated.
    .DESCRIPTION
        Reads the "Run as administrator" flag straight from the .lnk file: byte 21 (0x15), bit 6 (0x20).
        WScript.Shell does not expose the flag, so the file is read as bytes.
    .PARAMETER Location
        The location of the shortcut to read the flag from.
    .OUTPUTS
        Boolean indicating whether the shortcut launches its target elevated.
    .EXAMPLE
        Test-ShortcutElevated -Location "C:\Users\me\Desktop\MyApp.lnk"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $bytes = [System.IO.File]::ReadAllBytes($Location)

    return ($bytes[0x15] -band 0x20) -eq 0x20
}
