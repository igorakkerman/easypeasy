. "$PSScriptRoot\shortcut.ps1"

$wshShell = New-Object -ComObject WScript.Shell
$allUsersProgramsPath = $wshShell.SpecialFolders("AllUsersPrograms")

# https://www.vbsedit.com/html/a239a3ac-e51c-4e70-859e-d2d8c2eb3135.asp
# $windowStyleDefault = 1
$windowStyleMaximized = 3
$windowStyleMinimized = 7

function Get-StartMenuProgramsPath {
    [CmdletBinding()]
    param ()

    return $allUsersProgramsPath

    <#
    .SYNOPSIS
        Returns the path to Start Menu > Programs.

    .DESCRIPTION
        Returns the path to the All Users Start Menu Programs folder.

    .OUTPUTS
        string - Path to the All Users Start Menu Programs folder.
    #>
}

function New-StartMenuProgramsFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $AppName
    )

    $shortcutFolderName = "$allUsersProgramsPath\$AppName"
    New-Item -ItemType Directory $shortcutFolderName -Force | Out-Null
    
    return $shortcutFolderName

    <#
    .SYNOPSIS
        Creates a new folder in Start Menu > Programs.

    .DESCRIPTION
        Creates a new folder in the All Users Start Menu Programs folder.

    .PARAMETER AppName
        The name of the application. This will be used as the name of the folder in the Start Menu > Programs folder.

    .OUTPUTS
        string - Path to the newly created folder in the All Users Start Menu Programs folder.
    #>
}

function New-StartMenuShortcut {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $AppName,

        [Parameter(Mandatory = $true)]
        [string] $Executable,

        [Parameter(Mandatory = $false)]
        [string] $Arguments,

        [Parameter(Mandatory = $false)]
        [Alias("Icon")]
        [string] $IconLocation
    )

    # infer the app name
    $shortcutAppName = if ($AppName) { $AppName } else { ((Get-Item $Executable).BaseName) }

    $shortcutFolder = New-StartMenuProgramsFolder -AppName $shortcutAppName
    $shortcutPath = "$shortcutFolder\$shortcutAppName.lnk"
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Executable
    $shortcut.Arguments = $Arguments
    If ($IconLocation) {
        $shortcut.IconLocation = "$IconLocation,0"
    }
    $shortcut.Save()

    return $shortcutPath

    <#
    .SYNOPSIS
        Creates a new shortcut in Start Menu > Programs.

    .DESCRIPTION
        Creates a new shortcut in the All Users Start Menu Programs folder.

    .PARAMETER AppName
        The name of the application. This will be used as the name of the folder in the Start Menu > Programs folder.

    .PARAMETER Executable
        The path to the executable.

    .PARAMETER Arguments
        The arguments to pass to the executable.

    .PARAMETER IconLocation
        The path to the icon file to use for the shortcut.

    .OUTPUTS
        string - Path to the newly created shortcut in the All Users Start Menu Programs folder.
    #>
}

function New-PowershellStartMenuShortcut {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Script")]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [Alias("App")]
        [string] $AppName,

        [Parameter(Mandatory = $false)]
        [Alias("FolderName", "Folder")]
        [string] $GroupName,

        [Parameter(Mandatory = $false)]
        [Alias("Administrator", "Admin", "Elevate")]
        [switch] $RunAsAdministrator = $false,

        [Parameter(Mandatory = $false)]
        [switch] $Visible = $false,

        [Parameter(Mandatory = $false)]
        [switch] $Maximized = $false,

        [Parameter(Mandatory = $false)]
        [Alias("NoExit")]
        [switch] $KeepOpen = $false
    )

    $shortcutFolder = if ($GroupName -ne "") {
        New-StartMenuProgramsFolder -AppName $GroupName
    }
    else {
        Get-StartMenuProgramsPath
    }

    $arguments = @()
    if ($KeepOpen) {
        $arguments += "-NoExit"
    }
    $arguments += "-Command `"$Command`""

    $shortcutPath = "$shortcutFolder\$AppName.lnk"
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "pwsh"
    $shortcut.Arguments = $arguments -join ' '
    if (-not $Visible) {
        $shortcut.WindowStyle = $windowStyleMinimized
    }
    if ($Maximized) {
        $shortcut.WindowStyle = $windowStyleMaximized
    }
    $shortcut.Save()

    if ($RunAsAdministrator) {
        Set-ShortcutRunAsAdministrator $shortcutPath
    }

    return $shortcutPath

    <#
    .SYNOPSIS
        Creates a new shortcut that runs a PowerShell command in Start Menu > Programs.

    .DESCRIPTION
        Creates a new shortcut that runs a PowerShell command in the All Users Start Menu Programs folder.

    .PARAMETER Command
        The PowerShell command to run.

    .PARAMETER AppName
        The name of the application. This will be used as the name of the shortcut in the Start Menu > Programs folder.

    .PARAMETER GroupName
        The name of the group to create the shortcut in. If not specified, the shortcut will be created in the Start Menu > Programs folder.

    .PARAMETER RunAsAdministrator
        Whether to run the PowerShell command as an administrator.

    .PARAMETER Visible
        Whether to show the PowerShell window when the shortcut is run.

    .PARAMETER Maximized
        Whether to maximize the PowerShell window when the shortcut is run.

    .PARAMETER KeepOpen
        Whether to keep the PowerShell window open after the command has finished running.

    .OUTPUTS
        string - Path to the newly created shortcut in the All Users Start Menu Programs folder.
    #>
}
