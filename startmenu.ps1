. "$PSScriptRoot\shortcut.ps1"

$wshShell = New-Object -ComObject WScript.Shell
$allUsersProgramsPath = $wshShell.SpecialFolders("AllUsersPrograms")
$userProgramsPath = $wshShell.SpecialFolders("Programs")

# https://www.vbsedit.com/html/a239a3ac-e51c-4e70-859e-d2d8c2eb3135.asp
# $windowStyleDefault = 1
$windowStyleMaximized = 3
$windowStyleMinimized = 7

function Get-StartMenuProgramsPath {
    <#
    .SYNOPSIS
        Returns the path to Start Menu > Programs.

    .DESCRIPTION
        Returns the path to the Start Menu Programs folder, for all users (the default) or the current user.

    .PARAMETER AllUsers
        Return the All Users (machine) Start Menu Programs folder. This is the default. Aliases: Machine, All.

    .PARAMETER User
        Return the current user's Start Menu Programs folder.

    .OUTPUTS
        string - Path to the Start Menu Programs folder.

    .NOTES
        Default scope is AllUsers (machine) for backward compatibility. In v2 the default will change to User (current user).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    return $User ? $userProgramsPath : $allUsersProgramsPath
}

function New-StartMenuProgramsFolder {
    <#
    .SYNOPSIS
        Creates a new folder in Start Menu > Programs.

    .DESCRIPTION
        Creates a new folder in the Start Menu Programs folder, for all users (the default) or the current user.

    .PARAMETER Name
        The name of the folder in the Start Menu > Programs folder.

    .PARAMETER AllUsers
        Create the folder in the All Users (machine) Start Menu Programs folder. This is the default. Aliases: Machine, All.

    .PARAMETER User
        Create the folder in the current user's Start Menu Programs folder.

    .OUTPUTS
        string - Path to the newly created folder in the Start Menu Programs folder.

    .NOTES
        Default scope is AllUsers (machine) for backward compatibility. In v2 the default will change to User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("AppName")] # DEPRECATED!
        [Alias("Folder", "Group")]
        [string] $Name,

        [Parameter(Mandatory = $false, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    $programsPath = $User ? $userProgramsPath : $allUsersProgramsPath
    $shortcutFolderName = "$programsPath\$Name"
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
        Creates a new shortcut in the Start Menu Programs folder, for all users (the default) or the current user.

    .PARAMETER Name
        The name of the application. This will be used as the name of the shortcut in the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in the Start Menu > Programs folder. Default: $Name

    .PARAMETER Executable
        The path to the executable.

    .PARAMETER Arguments
        The arguments to pass to the executable.

    .PARAMETER Icon
        The path to the icon file to use for the shortcut.

    .PARAMETER Force
        Overwrite the shortcut if it already exists. Without -Force, a terminating error is reported when the shortcut exists.

    .PARAMETER AllUsers
        Create the shortcut in the All Users (machine) Start Menu Programs folder. This is the default. Aliases: Machine, All.

    .PARAMETER User
        Create the shortcut in the current user's Start Menu Programs folder.

    .OUTPUTS
        string - Path to the newly created shortcut in the Start Menu Programs folder.

    .NOTES
        Default scope is AllUsers (machine) for backward compatibility. In v2 the default will change to User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("App", "AppName")]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [Alias("Group")]
        [string] $Folder,

        [Parameter(Mandatory = $true)]
        [string] $Executable,

        [Parameter(Mandatory = $false)]
        [string] $Arguments,

        [Parameter(Mandatory = $false)]
        [Alias("IconLocation")]
        [string] $Icon,

        [Parameter(Mandatory = $false)]
        [switch] $Force,

        [Parameter(Mandatory = $false, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    # infer the shortcut name
    $shortcutName = if ($Name) { $Name } else { ((Get-Item $Executable).BaseName) }

    $folderName = if ($Folder) { $Folder } else { $shortcutName }

    $shortcutFolder = New-StartMenuProgramsFolder -Name $folderName -User:$User
    $shortcutPath = "$shortcutFolder\$shortcutName.lnk"

    if (-not $Force -and (Test-Path -LiteralPath $shortcutPath)) {
        Write-Error "Shortcut already exists: '$shortcutPath'. Use -Force to overwrite." -ErrorAction Stop
    }

    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Executable
    $shortcut.Arguments = $Arguments
    If ($Icon) {
        $shortcut.IconLocation = "$Icon,0"
    }
    
    if ($PSCmdlet.ShouldProcess($shortcutPath, "Create shortcut")) {
        $shortcut.Save()
    }

    return $shortcutPath
}

function Remove-StartMenuShortcut {
    <#
    .SYNOPSIS
        Removes a shortcut from Start Menu > Programs.

    .DESCRIPTION
        Removes a shortcut from the Start Menu Programs folder, for all users (the default) or the current user.
        Mirrors New-StartMenuShortcut: the shortcut is expected at <Programs>\<Folder>\<Name>.lnk, where Folder
        defaults to Name. After removing the shortcut, its containing folder is removed too if it is now empty.
        If the shortcut does not exist, a terminating error is reported.

    .PARAMETER Name
        The name of the shortcut to remove from the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in the Start Menu > Programs folder that contains the shortcut. Default: $Name

    .PARAMETER AllUsers
        Remove the shortcut from the All Users (machine) Start Menu Programs folder. This is the default. Aliases: Machine, All.

    .PARAMETER User
        Remove the shortcut from the current user's Start Menu Programs folder.

    .NOTES
        Default scope is AllUsers (machine) for backward compatibility. In v2 the default will change to User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("App", "AppName")]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [Alias("Group")]
        [string] $Folder,

        [Parameter(Mandatory = $false, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    $programsPath = $User ? $userProgramsPath : $allUsersProgramsPath
    $folderName = if ($Folder) { $Folder } else { $Name }
    $shortcutFolder = "$programsPath\$folderName"
    $shortcutPath = "$shortcutFolder\$Name.lnk"

    if (-not (Test-Path -LiteralPath $shortcutPath)) {
        Write-Error "Shortcut not found: '$shortcutPath'" -ErrorAction Stop
    }

    if ($PSCmdlet.ShouldProcess($shortcutPath, "Remove shortcut")) {
        Remove-Item -LiteralPath $shortcutPath -Force

        # remove the containing folder if it is now empty, but never the Programs root
        if ($shortcutFolder -ne $programsPath -and -not (Get-ChildItem -LiteralPath $shortcutFolder -Force)) {
            Remove-Item -LiteralPath $shortcutFolder -Force
        }
    }
}

function New-PowershellStartMenuShortcut {
    <#
    .SYNOPSIS
        Creates a new shortcut that runs a PowerShell command in Start Menu > Programs.

    .DESCRIPTION
        Creates a new shortcut that runs a PowerShell command in the All Users Start Menu Programs folder.

    .PARAMETER Command
        The PowerShell command to run.

    .PARAMETER Name
        The name of the shortcut in the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in Start Menu > Programs to create the shortcut in. If not specified, the shortcut is created directly in Start Menu > Programs.

    .PARAMETER RunAsAdministrator
        Whether to run the PowerShell command as an administrator.

    .PARAMETER Visible
        Whether to show the PowerShell window when the shortcut is run.

    .PARAMETER Maximized
        Whether to maximize the PowerShell window when the shortcut is run.

    .PARAMETER KeepOpen
        Whether to keep the PowerShell window open after the command has finished running.

    .PARAMETER Icon
        The path to the icon file to use for the shortcut.

    .PARAMETER Force
        Overwrite the shortcut if it already exists. Without -Force, a terminating error is reported when the shortcut exists.

    .OUTPUTS
        string - Path to the newly created shortcut in the All Users Start Menu Programs folder.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Script")]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [Alias("App", "AppName")]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [Alias("Group", "GroupName")]
        [string] $Folder,

        [Parameter(Mandatory = $false)]
        [Alias("Administrator", "Admin", "Elevate")]
        [switch] $RunAsAdministrator = $false,

        [Parameter(Mandatory = $false)]
        [switch] $Visible = $false,

        [Parameter(Mandatory = $false)]
        [switch] $Maximized = $false,

        [Parameter(Mandatory = $false)]
        [Alias("NoExit")]
        [switch] $KeepOpen = $false,

        [Parameter(Mandatory = $false)]
        [Alias("IconLocation")]
        [string] $Icon,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    $shortcutFolder = if ($Folder) {
        New-StartMenuProgramsFolder -Name $Folder
    }
    else {
        Get-StartMenuProgramsPath
    }

    $arguments = @()
    if ($KeepOpen) {
        $arguments += "-NoExit"
    }
    $arguments += "-Command `"$Command`""

    $shortcutPath = "$shortcutFolder\$Name.lnk"

    if (-not $Force -and (Test-Path -LiteralPath $shortcutPath)) {
        Write-Error "Shortcut already exists: '$shortcutPath'. Use -Force to overwrite." -ErrorAction Stop
    }

    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "pwsh"
    $shortcut.Arguments = $arguments -join ' '
    if (-not $Visible) {
        $shortcut.WindowStyle = $windowStyleMinimized
    }
    if ($Maximized) {
        $shortcut.WindowStyle = $windowStyleMaximized
    }

    if ($Icon) {
        $shortcut.IconLocation = "$Icon,0"
    }

    if ($PSCmdlet.ShouldProcess($shortcutPath, "Create shortcut")) {
        $shortcut.Save()
    }

    if ($RunAsAdministrator) {
        Set-ShortcutRunAsAdministrator $shortcutPath
    }

    return $shortcutPath
}
