@{

    # Script module or binary module file associated with this manifest.
    RootModule           = 'easypeasy.psm1'

    # Version number of this module.
    ModuleVersion        = '1.6.1'

    # Supported PSEditions
    CompatiblePSEditions = @(
        'Core'
    )

    # ID used to uniquely identify this module
    GUID                 = '41fde4e3-aff9-4527-b12b-06c89ddddd19'

    # Author of this module
    Author               = 'Igor Akkerman'

    # Company or vendor of this module
    # CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright            = 'Copyright (c) 2025 Igor Akkerman. Licensed under the Apache License, Version 2.0'

    # Description of the functionality provided by this module
    Description          = 'Collection of utility functions and aliases to simplify and automate common tasks in Windows environments.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion    = '7.0'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules      = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies   = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess     = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess       = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess     = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules        = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport    = @(
        'Assert-Administrator',
        'Get-Timestamp',
        'Get-Usage',
        'Get-ProgramFilesFolder',
        'Get-MyDocumentsFolder',
        'Get-DesktopFolder',
        'Stop-Explorer',
        'Get-SystemPath',
        'Add-SystemPathLocation',
        'Remove-SystemPathLocation',
        'Backup-SystemPath',
        'Get-EnvironmentVariable',
        'Set-EnvironmentVariable',
        'Remove-EnvironmentVariable',
        'Set-ShortcutRunAsAdministrator',
        'New-StartMenuShortcut',
        'New-PowershellStartMenuShortcut',
        'Get-StartMenuProgramsPath',
        'New-StartMenuProgramsFolder',
        'Register-LogonTask',
        'Get-Theme',
        'Set-Theme',
        'Switch-Theme'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport      = @()

    # Variables to export from this module
    # VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport      = @(
        'getenv',
        'setenv',
        'rmenv',
        'path',
        'programs',
        'docs',
        'desktop',
        'sx',
        'time',
        'du',
        'theme'
    )

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    ModuleList           = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSEdition_Core', 'Windows', 'System', 'Environment', 'Path', 'EnvironmentVariable', 'Shortcut', 
                'StartMenu', 'LogonTask', 'Theme', 'Utility', 'Alias', 'Function', 'Automation', 'Productivity'
            )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/igorakkerman/easypeasy/blob/main/LICENSE.txt'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/igorakkerman/easypeasy'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

