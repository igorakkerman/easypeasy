# >_  easy𝓅ea𝓈y
*Productivity boost for PowerShell*

The *easypeasy* PowerShell module provides a set of utility functions and aliases to simplify and automate common tasks in Windows environments. It includes functions to work with
- system paths
- environment variables
- shortcuts
- scheduled tasks
- light and dark themes

## Functionality
### Light/Dark Theme operations

#### Switch-Theme

*Alias: `theme`*

Switches between light and dark theme.

#### Set-Theme

Activates the specified theme (light/dark).


### System PATH operations

#### Get-SystemPath

*Alias: `path`*

Returns the current system PATH locations.

#### Add-SystemPathLocation

Permanently adds a new location to the system PATH for the current user or the local machine.

*Example*:
```powershell
Add-SystemPathLocation -Machine "C:\Program Files\MyApp" -Front
```

#### Remove-SystemPathLocation

Removes a location from the system PATH.

#### Backup-SystemPath

Backs up the current system PATH environment variable to a file.

### Environment variable operations

#### Get-EnvironmentVariable

*Alias: `getenv`*

Retrieves the value of the specified environment variable.

#### Set-EnvironmentVariable

*Alias: `setenv`*

Permanently sets the value of the specified environment variable for the current user or the local machine.

```powershell
Set-EnvironmentVariable -User -Name "MY_VAR" -Value "my value"
```


#### Remove-EnvironmentVariable

*Alias: `rmenv`*

Removes the specified environment variable.

### Start Menu operations

#### New-StartMenuShortcut

Creates a new shortcut in the Start Menu.

*Example:*
```powershell
New-StartMenuShortcut -AppName "MyApp" -Executable "C:\Program Files\MyApp\MyApp.exe" -Arguments "-Debug"
```

#### New-PowershellStartMenuShortcut

Creates a new PowerShell script shortcut in the Start Menu.

#### Get-StartMenuProgramsPath

Returns the path to the Start Menu Programs folder.

#### New-StartMenuProgramsFolder

Creates a new folder in the Start Menu Programs folder.

#### Set-ShortcutRunAsAdministrator

Modifies a shortcut to always run as administrator.

### System startup operations

#### Register-LogonUserTask

Registers a new task to run at user logon.

### Utilities

#### Get-Timestamp

*Alias: `time`*

Returns the current timestamp in a simple format.

#### Get-Usage

*Alias: `du`*

Gets disk usage information for the specified path.

#### Get-MyDocumentsFolder

*Alias: `docs`*

Returns the path to the current user's "My Documents" folder.

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
Thanks to everyone supporting and contributing to *easypeasy*
and to ChatGPT for writing most of this documentation 😁🦥
