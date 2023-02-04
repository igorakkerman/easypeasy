$wshShell = New-Object -ComObject WScript.Shell
$allUsersProgramsPath = $wshShell.SpecialFolders("AllUsersPrograms")

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
        [string] $Arguments
    )

    # infer the app name
    $shortcutAppName = if ($AppName) { $AppName } else { ((Get-Item $Executable).BaseName) }

    $shortcutFolder = New-StartMenuProgramsFolder -AppName $shortcutAppName
    $shortcutPath = "$shortcutFolder\$shortcutAppName.lnk"
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Executable
    $shortcut.Arguments = $Arguments
    $shortcut.Save()
}

function New-PowershellStartMenuShortcut {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [string] $AppName
    )

    $shortcutFolder = New-StartMenuProgramsFolder -AppName $AppName
    $shortcutPath = "$shortcutFolder\$AppName.lnk"
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "pwsh"
    $shortcut.Arguments = "-Command `"$Command`""
    $shortcut.WindowStyle = $windowStyleMinimized
    $shortcut.Save()
}
