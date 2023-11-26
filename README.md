# >_  easy𝓅ea𝓈y
*Productivity boost for PowerShell*

The *easypeasy* PowerShell module provides a set of utility functions and aliases to simplify and automate common tasks in Windows environments:
- manage locations on the system path
- manage environment variables
- create start menu shortcuts
- create scheduled tasks
- switch between light and dark themes
- create timestamps
- show disk usage
- verify administrator privileges

## Functionality

### Manage locations on the system path

#### Get-SystemPath

*Alias: `path`*

Returns the current system PATH locations.

#### Add-SystemPathLocation

Permanently adds a new location to the system PATH.

*Example*:
```powershell
Add-SystemPathLocation -Machine "C:\Program Files\MyApp" -Front
```

#### Remove-SystemPathLocation

Removes a location from the system PATH.

#### Backup-SystemPath

Backs up the current system PATH environment variable to a file.

### Manage environment variables

#### Get-EnvironmentVariable

*Alias: `getenv`*

Retrieves the value of an environment variable.

#### Set-EnvironmentVariable

*Alias: `setenv`*

Permanently sets the value of an environment variable.

```powershell
setenv -User JAVA_HOME "C:\Java\jdk"
```

#### Remove-EnvironmentVariable

*Alias: `rmenv`*

Removes the specified environment variable.

### Create start menu shortcuts

#### New-StartMenuShortcut

Creates a shortcut to start an application in the Start Menu.

*Example:*
```powershell
New-StartMenuShortcut -AppName "MyApp" -Executable "C:\Program Files\MyApp\MyApp.exe" -Arguments "-Debug"
```

#### New-PowershellStartMenuShortcut

Creates a shortcut to run a PowerShell script in the Start Menu.

#### New-StartMenuProgramsFolder

Creates a new folder in the Start Menu Programs folder.

#### Get-StartMenuProgramsPath

Returns the path to the Start Menu Programs folder.

#### Set-ShortcutRunAsAdministrator

Modifies a shortcut to always run as administrator.

### Create scheduled tasks

#### Register-LogonTask

Registers a task to run at user logon.

### Switch between light and dark themes

#### Switch-Theme

*Alias: `theme`*

Switches between light and dark theme.

*Example:*
```powershell
# use dark theme
theme dark

# switch theme from light to dark or vice versa
theme
```

#### Set-Theme

Activates the specified theme (light/dark).

### Utilities

#### Get-Timestamp

*Alias: `time`*

Returns the current timestamp in a simple format.

#### Assert-Administrator
Verifies that the current user is an administrator.

#### Get-Usage

*Alias: `du`*

Gets disk usage information for the specified path.

#### Get-MyDocumentsFolder

*Alias: `docs`*

Returns the path to the current user's "My Documents" folder.

## Installation from PowerShell Gallery

To install the *easypeasy* module from the PowerShell Gallery, run the following command in PowerShell:

```powershell
Install-Module easypeasy
```

## Manual Installation

To install the *easypeasy* module, follow these steps:

1. Download the module folder from GitHub to your computer.

1. Open PowerShell and run the following command to check the installation path for PowerShell modules: `$env:PSModulePath`

1. Copy the *easypeasy* module folder to one of the paths listed in the output of the previous command, e.g. the user's module path: `$HOME\Documents\WindowsPowerShell\Modules\`

1. Add `Import-Module easypeasy` to your profile, e.g. `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

1. Open a new PowerShell session or reload your profile to make the module available. You can check if the module is available by running: `Get-Module -ListAvailable`

## Contributing
Please contribute to the *easypeasy* module. Issues and pull requests are very welcome. Thank you!

## License
The *easypeasy* module is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments
Thanks to everyone supporting and contributing to *easypeasy*.
