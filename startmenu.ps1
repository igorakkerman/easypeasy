. "$PSScriptRoot\shortcut.ps1"

$wshShell = New-Object -ComObject WScript.Shell
$allUsersProgramsPath = $wshShell.SpecialFolders("AllUsersPrograms")

# https://www.vbsedit.com/html/a239a3ac-e51c-4e70-859e-d2d8c2eb3135.asp
# $windowStyleDefault = 1
# $windowStyleMaximized = 3
$windowStyleMinimized = 7

function Get-StartMenuProgramsPath {
    return $allUsersProgramsPath
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
    $shortcut.Save()

    if ($RunAsAdministrator) {
        Set-ShortcutRunAsAdministrator $shortcutPath
    }
}
