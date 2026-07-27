$allUsersProgramsLocation = $wshShell.SpecialFolders("AllUsersPrograms")
$userProgramsLocation = $wshShell.SpecialFolders("Programs")

function Get-StartMenuProgramsLocation {
    <#
    .SYNOPSIS
        Returns the path to Start Menu > Programs.

    .DESCRIPTION
        Returns the path to the Start Menu Programs folder, for the current user (the default) or for all users.

    .PARAMETER AllUsers
        Return the All Users (machine) Start Menu Programs folder. Aliases: Machine, All.

    .PARAMETER User
        Return the current user's Start Menu Programs folder. (Default.)

    .OUTPUTS
        string - Path to the Start Menu Programs folder.

    .NOTES
        Default scope is User (current user).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    return $AllUsers ? $allUsersProgramsLocation : $userProgramsLocation
}

function New-StartMenuProgramsFolder {
    <#
    .SYNOPSIS
        Creates a new folder in Start Menu > Programs.

    .DESCRIPTION
        Creates a new folder in the Start Menu Programs folder, for the current user (the default) or for all users.

    .PARAMETER Name
        The name of the folder in the Start Menu > Programs folder.

    .PARAMETER AllUsers
        Create the folder in the All Users (machine) Start Menu Programs folder. Aliases: Machine, All.

    .PARAMETER User
        Create the folder in the current user's Start Menu Programs folder. (Default.)

    .OUTPUTS
        string - Path to the newly created folder in the Start Menu Programs folder.

    .NOTES
        Default scope is User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $programsLocation = $AllUsers ? $allUsersProgramsLocation : $userProgramsLocation
    $shortcutFolderName = "$programsLocation\$Name"
    if ($PSCmdlet.ShouldProcess($shortcutFolderName, "Create folder")) {
        New-Item -ItemType Directory $shortcutFolderName -Force | Out-Null
    }
    return $shortcutFolderName
}

function New-StartMenuShortcut {
    <#
    .SYNOPSIS
        Creates a new shortcut in Start Menu > Programs.

    .DESCRIPTION
        Creates a new shortcut in the Start Menu Programs folder, for the current user (the default) or for all users.

    .PARAMETER Name
        The name of the shortcut in the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in Start Menu > Programs to create the shortcut in. If not specified, the shortcut is created directly in Start Menu > Programs.

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

    .PARAMETER Force
        Overwrite the shortcut if it already exists. Without -Force, a terminating error is reported when the shortcut exists.

    .PARAMETER AllUsers
        Create the shortcut in the All Users (machine) Start Menu Programs folder. Aliases: Machine, All.

    .PARAMETER User
        Create the shortcut in the current user's Start Menu Programs folder. (Default.)

    .OUTPUTS
        Shortcut record describing the created shortcut, as read by Get-Shortcut. Nothing under -WhatIf.

    .EXAMPLE
        New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe"

    .EXAMPLE
        New-StartMenuShortcut -Name MyApp -Folder MyCompany -Target "C:\Program Files\MyApp\MyApp.exe" `
            -Arguments "--profile Default" `
            -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3) `
            -WindowStyle Maximized -Elevated

    .NOTES
        Default scope is User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    # the type name is a string: the Shortcut class lives in another file, unresolvable at definition time
    [OutputType("Shortcut")]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Folder,

        [Parameter(Mandatory = $true)]
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
        [switch] $Elevated,

        [Parameter(Mandatory = $false)]
        [switch] $Force,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $shortcutFolder = $Folder `
        ? (New-StartMenuProgramsFolder -Name $Folder -AllUsers:$AllUsers) `
        : (Get-StartMenuProgramsLocation -AllUsers:$AllUsers)

    # an omitted run location falls back to the folder of the target, as New-Shortcut defaults it
    $shortcutRunLocation = $PSBoundParameters.ContainsKey("RunLocation") ? $RunLocation : (Split-Path -Parent $Target)

    # New-Shortcut gates the creation behind its own ShouldProcess, inheriting -WhatIf / -Confirm from here.
    # -CreateFolder states that the folder is there: under -WhatIf New-StartMenuProgramsFolder only reports it.
    return New-Shortcut `
        -Location "$shortcutFolder\$Name.lnk" `
        -Target $Target `
        -Arguments $Arguments `
        -RunLocation $shortcutRunLocation `
        -Description $Description `
        -Icon $Icon `
        -Hotkey $Hotkey `
        -WindowStyle $WindowStyle `
        -Elevated:$Elevated `
        -CreateFolder `
        -Force:$Force
}

function Remove-StartMenuShortcut {
    <#
    .SYNOPSIS
        Removes a shortcut from Start Menu > Programs.

    .DESCRIPTION
        Removes a shortcut from the Start Menu Programs folder, for the current user (the default) or for all users.
        Mirrors New-StartMenuShortcut: the shortcut is expected at <Programs>\<Folder>\<Name>.lnk, or directly at
        <Programs>\<Name>.lnk when Folder is not specified. After removing the shortcut, its containing folder is
        removed too if it is now empty. If the shortcut does not exist, a terminating error is reported.

    .PARAMETER Name
        The name of the shortcut to remove from the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in Start Menu > Programs that contains the shortcut. If not specified, the shortcut is expected directly in Start Menu > Programs.

    .PARAMETER AllUsers
        Remove the shortcut from the All Users (machine) Start Menu Programs folder. Aliases: Machine, All.

    .PARAMETER User
        Remove the shortcut from the current user's Start Menu Programs folder. (Default.)

    .NOTES
        Default scope is User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Folder,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $programsLocation = $AllUsers ? $allUsersProgramsLocation : $userProgramsLocation
    $shortcutFolder = $Folder ? "$programsLocation\$Folder" : $programsLocation
    $shortcutLocation = "$shortcutFolder\$Name.lnk"

    if (-not (Test-Path -LiteralPath $shortcutLocation)) {
        Write-Error "Shortcut not found: '$shortcutLocation'" -ErrorAction Stop
    }

    if ($PSCmdlet.ShouldProcess($shortcutLocation, "Remove shortcut")) {
        Remove-Item -LiteralPath $shortcutLocation -Force

        # remove the containing folder if it is now empty, but never the Programs root
        if ($shortcutFolder -ne $programsLocation -and -not (Get-ChildItem -LiteralPath $shortcutFolder -Force)) {
            Remove-Item -LiteralPath $shortcutFolder -Force
        }
    }
}

function New-PowershellStartMenuShortcut {
    <#
    .SYNOPSIS
        Creates a new shortcut that runs a PowerShell command in Start Menu > Programs.

    .DESCRIPTION
        Creates a new shortcut that runs a PowerShell command in the Start Menu Programs folder, for the current user (the default) or for all users.

    .PARAMETER Command
        The PowerShell command to run.

    .PARAMETER Name
        The name of the shortcut in the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in Start Menu > Programs to create the shortcut in. If not specified, the shortcut is created directly in Start Menu > Programs.

    .PARAMETER KeepOpen
        Whether to keep the PowerShell window open after the command has finished running. Alias: NoExit.

    .PARAMETER RunLocation
        The location the command runs in, shown as "Start in" in the shortcut properties.

    .PARAMETER Description
        The free-text description of the shortcut, shown as its comment / tooltip.

    .PARAMETER Icon
        The icon of the shortcut, as a ShortcutIcon record built by New-ShortcutIcon or read by Get-Shortcut.
        Default: no icon.

    .PARAMETER Hotkey
        The keyboard shortcut that opens the shortcut, e.g. "Ctrl+Alt+N".

    .PARAMETER WindowStyle
        The window state the PowerShell window launches in: Normal, Maximized or Minimized. Default: Minimized.

    .PARAMETER Elevated
        Run the PowerShell command elevated, ticked as "Run as administrator" in the advanced properties.

    .PARAMETER Force
        Overwrite the shortcut if it already exists. Without -Force, a terminating error is reported when the shortcut exists.

    .PARAMETER AllUsers
        Create the shortcut in the All Users (machine) Start Menu Programs folder. Aliases: Machine, All.

    .PARAMETER User
        Create the shortcut in the current user's Start Menu Programs folder. (Default.)

    .OUTPUTS
        Shortcut record describing the created shortcut, as read by Get-Shortcut. Nothing under -WhatIf.

    .EXAMPLE
        New-PowershellStartMenuShortcut -Name "Kill Node.js" -Command "Stop-Process -Name node -Force"

    .EXAMPLE
        New-PowershellStartMenuShortcut -Name "Run System Update" -Script "C:\Scripts\system-update.ps1" `
            -KeepOpen -WindowStyle Maximized -Elevated

    .NOTES
        Default scope is User (current user).
        Alias: Script for -Command, NoExit for -KeepOpen.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    # the type name is a string: the Shortcut class lives in another file, unresolvable at definition time
    [OutputType("Shortcut")]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Script")]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Folder,

        [Parameter(Mandatory = $false)]
        [Alias("NoExit")]
        [switch] $KeepOpen,

        [Parameter(Mandatory = $false)]
        [string] $RunLocation,

        [Parameter(Mandatory = $false)]
        [string] $Description,

        [Parameter(Mandatory = $false)]
        [ShortcutIcon] $Icon,

        [Parameter(Mandatory = $false)]
        [string] $Hotkey,

        [Parameter(Mandatory = $false)]
        [ShortcutWindowStyle] $WindowStyle = [ShortcutWindowStyle]::Minimized,

        [Parameter(Mandatory = $false)]
        [switch] $Elevated,

        [Parameter(Mandatory = $false)]
        [switch] $Force,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $shortcutFolder = $Folder `
        ? (New-StartMenuProgramsFolder -Name $Folder -AllUsers:$AllUsers) `
        : (Get-StartMenuProgramsLocation -AllUsers:$AllUsers)

    $arguments = @()
    if ($KeepOpen) {
        $arguments += "-NoExit"
    }
    $arguments += "-Command `"$Command`""

    # New-Shortcut gates the creation behind its own ShouldProcess, inheriting -WhatIf / -Confirm from here.
    # -CreateFolder states that the folder is there: under -WhatIf New-StartMenuProgramsFolder only reports it.
    # an omitted run location stays empty: the bare pwsh target has no folder to fall back to.
    return New-Shortcut `
        -Location "$shortcutFolder\$Name.lnk" `
        -Target "pwsh" `
        -Arguments ($arguments -join ' ') `
        -RunLocation $RunLocation `
        -Description $Description `
        -Icon $Icon `
        -Hotkey $Hotkey `
        -WindowStyle $WindowStyle `
        -Elevated:$Elevated `
        -CreateFolder `
        -Force:$Force
}
