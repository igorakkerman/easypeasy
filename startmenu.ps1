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

    return $AllUsers ? $allUsersProgramsPath : $userProgramsPath
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
        [Alias("AppName")] # DEPRECATED!
        [Alias("Folder")]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $programsPath = $AllUsers ? $allUsersProgramsPath : $userProgramsPath
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
        Creates a new shortcut in the Start Menu Programs folder, for the current user (the default) or for all users.

    .PARAMETER Name
        The name of the application. This will be used as the name of the shortcut in the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in the Start Menu > Programs folder. Default: $Name

    .PARAMETER Executable
        The path to the executable.

    .PARAMETER Arguments
        The arguments to pass to the executable.

    .PARAMETER Icon
        The icon to use for the shortcut, as a combined location in the form "file,index", e.g. "C:\Program Files\MyApp\MyApp.exe,0".
        Cannot be combined with -IconLocation or -IconIndex.

    .PARAMETER IconLocation
        The path to the icon file to use for the shortcut. Cannot be combined with -Icon. Alias: IconFile.

    .PARAMETER IconIndex
        The index of the icon within the icon file given by -IconLocation. Default: 0. Cannot be combined with -Icon.

    .PARAMETER Force
        Overwrite the shortcut if it already exists. Without -Force, a terminating error is reported when the shortcut exists.

    .PARAMETER AllUsers
        Create the shortcut in the All Users (machine) Start Menu Programs folder. Aliases: Machine, All.

    .PARAMETER User
        Create the shortcut in the current user's Start Menu Programs folder. (Default.)

    .OUTPUTS
        string - Path to the newly created shortcut in the Start Menu Programs folder.

    .NOTES
        Default scope is User (current user).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("App", "AppName")]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Folder,

        [Parameter(Mandatory = $true)]
        [string] $Executable,

        [Parameter(Mandatory = $false)]
        [string] $Arguments,

        [Parameter(Mandatory = $false)]
        [string] $Icon,

        [Parameter(Mandatory = $false)]
        [Alias("IconFile")]
        [string] $IconLocation,

        [Parameter(Mandatory = $false)]
        [int] $IconIndex = 0,

        [Parameter(Mandatory = $false)]
        [switch] $Force,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    if ($Icon -and ($IconLocation -or $PSBoundParameters.ContainsKey("IconIndex"))) {
        Write-Error "-Icon cannot be combined with -IconLocation or -IconIndex." -ErrorAction Stop
    }

    # infer the shortcut name
    $shortcutName = $Name ? $Name : (Get-Item $Executable).BaseName

    $folderName = $Folder ? $Folder : $shortcutName

    $shortcutFolder = New-StartMenuProgramsFolder -Name $folderName -AllUsers:$AllUsers
    $shortcutPath = "$shortcutFolder\$shortcutName.lnk"

    if (-not $Force -and (Test-Path -LiteralPath $shortcutPath)) {
        Write-Error "Shortcut already exists: '$shortcutPath'. Use -Force to overwrite." -ErrorAction Stop
    }

    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Executable
    $shortcut.Arguments = $Arguments
    if ($Icon) {
        $shortcut.IconLocation = $Icon
    }
    elseif ($IconLocation) {
        $shortcut.IconLocation = "$IconLocation,$IconIndex"
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
        Removes a shortcut from the Start Menu Programs folder, for the current user (the default) or for all users.
        Mirrors New-StartMenuShortcut: the shortcut is expected at <Programs>\<Folder>\<Name>.lnk, where Folder
        defaults to Name. After removing the shortcut, its containing folder is removed too if it is now empty.
        If the shortcut does not exist, a terminating error is reported.

    .PARAMETER Name
        The name of the shortcut to remove from the Start Menu > Programs folder.

    .PARAMETER Folder
        The name of the folder in the Start Menu > Programs folder that contains the shortcut. Default: $Name

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
        [Alias("App", "AppName")]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Folder,

        [Parameter(Mandatory = $true, ParameterSetName = "AllUsers")]
        [Alias("Machine", "All")]
        [switch] $AllUsers,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $programsPath = $AllUsers ? $allUsersProgramsPath : $userProgramsPath
    $folderName = $Folder ? $Folder : $Name
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
        Creates a new shortcut that runs a PowerShell command in the current user's Start Menu Programs folder.

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
        The icon to use for the shortcut, as a combined location in the form "file,index", e.g. "C:\Program Files\MyApp\MyApp.exe,0".
        Cannot be combined with -IconLocation or -IconIndex.

    .PARAMETER IconLocation
        The path to the icon file to use for the shortcut. Cannot be combined with -Icon. Alias: IconFile.

    .PARAMETER IconIndex
        The index of the icon within the icon file given by -IconLocation. Default: 0. Cannot be combined with -Icon.

    .PARAMETER Force
        Overwrite the shortcut if it already exists. Without -Force, a terminating error is reported when the shortcut exists.

    .OUTPUTS
        string - Path to the newly created shortcut in the current user's Start Menu Programs folder.
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
        [string] $Icon,

        [Parameter(Mandatory = $false)]
        [Alias("IconFile")]
        [string] $IconLocation,

        [Parameter(Mandatory = $false)]
        [int] $IconIndex = 0,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    if ($Icon -and ($IconLocation -or $PSBoundParameters.ContainsKey("IconIndex"))) {
        Write-Error "-Icon cannot be combined with -IconLocation or -IconIndex." -ErrorAction Stop
    }

    $shortcutFolder = $Folder `
        ? (New-StartMenuProgramsFolder -Name $Folder) `
        : (Get-StartMenuProgramsPath)

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
        $shortcut.IconLocation = $Icon
    }
    elseif ($IconLocation) {
        $shortcut.IconLocation = "$IconLocation,$IconIndex"
    }

    if ($PSCmdlet.ShouldProcess($shortcutPath, "Create shortcut")) {
        $shortcut.Save()
    }

    if ($RunAsAdministrator) {
        Set-ShortcutRunAsAdministrator $shortcutPath
    }

    return $shortcutPath
}
