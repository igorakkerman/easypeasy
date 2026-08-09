BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Add-SystemPathLocation' {

    BeforeAll {
        # the fixture locations name no real folder, so the folder check is neutralized here;
        # it is exercised against the file system in its own contexts below
        Mock -ModuleName easypeasy Test-Path { $true }
    }

    BeforeEach {
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }
    }

    Context 'delegation' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the extended path via Set-SystemPath' {
            Add-SystemPathLocation -Location 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\New' -and $User }
        }

        It 'takes the location positionally' {
            Add-SystemPathLocation 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\New' }
        }

        It 'does not persist under -WhatIf' {
            Add-SystemPathLocation -Location 'C:\New' -User -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'targets the user scope by default' {
            Add-SystemPathLocation -Location 'C:\New'

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and -not $Machine }
        }

        It 'targets the machine scope with -Machine' {
            Add-SystemPathLocation -Location 'C:\New' -Machine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and -not $User }
        }
    }

    Context 'from the pipeline' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'takes a piped entry as the location it stores' {
            New-PathEntries 'C:\New' | Add-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\New' }
        }

        It 'takes a piped entry reference verbatim, unexpanded' {
            New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32' | Add-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;%SystemRoot%\S32' }
        }

        It 'takes the entry passed on inside ForEach-Object' {
            New-PathEntries 'C:\New' | ForEach-Object { Add-SystemPathLocation $_ -User }

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\New' }
        }

        It 'appends every piped location in a single write, keeping their order' {
            'C:\New', 'C:\Other' | Add-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\New;C:\Other' }
        }

        It 'puts every piped location in front with -First, keeping their order' {
            'C:\New', 'C:\Other' | Add-SystemPathLocation -User -First

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\New;C:\Other;C:\Old' }
        }

        It 'adds every location given as an argument list' {
            Add-SystemPathLocation -Location 'C:\New', 'C:\Other' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\New;C:\Other' }
        }

        It 'warns for each piped location that is already present' {
            $script:currentEntries = New-PathEntries 'C:\Old;C:\New'

            'C:\Old', 'C:\New' | Add-SystemPathLocation -User `
                -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -HaveCount 2
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'writes nothing under -WhatIf' {
            'C:\New', 'C:\Other' | Add-SystemPathLocation -User -WhatIf

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'reads and writes nothing for an empty pipeline' {
            @() | Add-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Get-SystemPath -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'a location list where one location names no existing folder' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
            Mock -ModuleName easypeasy Test-Path { $LiteralPath -ne 'C:\Missing' }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'reports the missing folder and writes neither location' {
            { 'C:\New', 'C:\Missing' | Add-SystemPathLocation -User -ErrorAction Stop } |
                Should -Throw '*C:\Missing*'

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'idempotent when the location is already present' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Add-PathLocation runs; the location is already present.
            $script:currentEntries = New-PathEntries 'C:\Exists'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'does not throw, even with -ErrorAction Stop' {
            { Add-SystemPathLocation -Location 'C:\Exists' -User -ErrorAction Stop } |
                Should -Not -Throw
        }

        It 'warns that the location is already present' {
            Add-SystemPathLocation -Location 'C:\Exists' -User -WarningVariable warning -WarningAction SilentlyContinue
            $warning | Should -Match 'already on the system Path'
        }

        It 'does not persist when the location is already present' {
            Add-SystemPathLocation -Location 'C:\Exists' -User
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'holds a UNC root apart from a single leading backslash' {
            $script:currentEntries = New-PathEntries '\\server\share'

            Add-SystemPathLocation -Location '\server\share' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq '\\server\share;\server\share' }
        }

        It 'treats a location with repeated backslashes as present' {
            $script:currentEntries = New-PathEntries 'C:\Exists\bin'

            Add-SystemPathLocation -Location 'C:\Exists\\bin' -User -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'already on the system Path'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'moving an existing location to the front with -First' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Add-PathLocation runs; the location is already present in the middle.
            $script:currentEntries = New-PathEntries 'C:\A;C:\Exists;C:\B'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the location moved to the front' {
            Add-SystemPathLocation -Location 'C:\Exists' -First -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Exists;C:\A;C:\B' -and $User }
        }

        It 'does not throw for an existing location' {
            { Add-SystemPathLocation -Location 'C:\Exists' -First -User -ErrorAction Stop } |
                Should -Not -Throw
        }

        It 'moves the entry for a location with repeated backslashes' {
            $script:currentEntries = New-PathEntries 'C:\A;C:\Exists\bin;C:\B'

            Add-SystemPathLocation -Location 'C:\Exists\\bin\' -First -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Exists\bin;C:\A;C:\B' }
        }

        It 'accepts the Front alias' {
            Add-SystemPathLocation -Location 'C:\Exists' -User -Front

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Exists;C:\A;C:\B' }
        }

        It 'moves the stored %...% form, not the resolved location, addressed by <address>' -ForEach @(
            @{ address = 'C:\WINDOWS\S32' }
            @{ address = '%SystemRoot%\S32' }
        ) {
            $script:currentEntries = @(New-PathEntries 'C:\A') +
                @(New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32') +
                @(New-PathEntries 'C:\B')

            Add-SystemPathLocation -Location $address -First -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq '%SystemRoot%\S32;C:\A;C:\B' }
        }

        It 'moves the stored form of an entry spelled with forward slashes' {
            $script:currentEntries = @(New-PathEntries 'C:\A') +
                @(New-PathEntry -StoredValue 'c:/fwd/slash/' -Location 'C:\fwd\slash') +
                @(New-PathEntries 'C:\B')

            Add-SystemPathLocation -Location 'C:\fwd\slash' -First -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'c:/fwd/slash/;C:\A;C:\B' }
        }
    }

    Context 'when not elevated' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy Assert-SudoAvailable { }
            Mock -ModuleName easypeasy Get-ProcessOnlyPathLocations { @{} }
            Mock -ModuleName easypeasy Sync-ProcessPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'runs the whole addition elevated for -Machine, passing no Path' {
            Add-SystemPathLocation -Location 'C:\New' -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Add-SystemPathLocation' -and
                $Command -contains '-Location' -and
                @($Command[2]).Count -eq 1 -and
                $Command[2] -contains 'C:\New' -and
                $Command -contains '-Machine' -and
                -not ($Command -join ' ').Contains('C:\Old')
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'passes every piped location on to the one elevated session' {
            'C:\New', 'C:\Other' | Add-SystemPathLocation -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Add-SystemPathLocation' -and
                $Command[2] -contains 'C:\New' -and
                $Command[2] -contains 'C:\Other' -and
                $Command -contains '-Machine'
            }
        }

        It 'passes -First on to the elevated session' {
            Add-SystemPathLocation -Location 'C:\New' -Machine -First

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains '-First'
            }
        }

        It 'passes -Force on to the elevated session' {
            Add-SystemPathLocation -Location 'C:\New' -Machine -Force

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains '-Force'
            }
        }

        It 'does not elevate for the user scope' {
            Add-SystemPathLocation -Location 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly
        }

        It 'does not elevate under -WhatIf' {
            Add-SystemPathLocation -Location 'C:\New' -Machine -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'does not elevate when the location is already present' {
            Add-SystemPathLocation -Location 'C:\Old' -Machine -WarningAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }

        It 'fails for -Machine before reading the Path when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Add-SystemPathLocation -Location 'C:\New' -Machine } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Get-SystemPath -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'expandable locations' {

        BeforeEach {
            $script:originalPath = $env:PATH
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'stores a %...% location as the reference, unexpanded' {
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location '%SystemRoot%\Tools' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;%SystemRoot%\Tools' }
        }

        It 'expands a %...% location into the entry Location' {
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location '%SystemRoot%\Tools' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].Location -eq "$env:SystemRoot\Tools" }
        }

        It 'keeps an existing entry stored form when another location is added' {
            $script:currentEntries = New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq '%SystemRoot%\S32;C:\New' }
        }

        It 'recognizes an existing %...% entry by its expanded location' {
            $script:currentEntries = New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location 'C:\WINDOWS\S32' -User -WarningAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'a location that names no existing folder' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # the folder check runs against the real file system, without touching it
            Mock -ModuleName easypeasy Test-Path { [System.IO.Directory]::Exists($LiteralPath) }
            Mock -ModuleName easypeasy Get-SystemPath { New-PathEntries 'C:\Old' }
            Mock -ModuleName easypeasy Set-SystemPath { }

            $script:missing = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid)"
        }

        AfterEach { $env:PATH = $originalPath }

        It 'reports a terminating error' {
            $errorRecord = { Add-SystemPathLocation -Location $missing -User } |
                Should -Throw '*not an existing folder*' -PassThru

            $errorRecord.CategoryInfo.Category | Should -Be 'ObjectNotFound'
            $errorRecord.FullyQualifiedErrorId | Should -BeLike 'PathLocationNotFound,*'
            $errorRecord.TargetObject | Should -Be $missing
        }

        It 'does not persist' {
            { Add-SystemPathLocation -Location $missing -User } | Should -Throw
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'reports the missing folder under -WhatIf too' {
            { Add-SystemPathLocation -Location $missing -User -WhatIf } | Should -Throw '*not an existing folder*'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'reports a location that is a file, not a folder' {
            { Add-SystemPathLocation -Location 'C:\Windows\notepad.exe' -User } |
                Should -Throw '*not an existing folder*'
        }

        It 'names a %...% reference whose variable is not set, and adds it anyway' {
            Add-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' -User `
                -ErrorVariable reported -ErrorAction SilentlyContinue

            $reported.FullyQualifiedErrorId | Should -BeLike 'EnvironmentVariableNotSet,*'
            $reported.TargetObject | Should -Be 'EASYPEASY_UNSET_XYZ'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].StoredValue -eq '%EASYPEASY_UNSET_XYZ%\bin' }
        }

        It 'names every unset variable of a location' {
            Add-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\%EASYPEASY_UNSET_ABC%\bin' -User `
                -ErrorVariable reported -ErrorAction SilentlyContinue

            $reported.TargetObject | Should -Be @('EASYPEASY_UNSET_XYZ', 'EASYPEASY_UNSET_ABC')
        }

        It 'keeps the reference as indirection, storing it verbatim' {
            Add-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' -User -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { [string]::IsNullOrEmpty($Entries[-1].Location) }
        }

        It 'names both forms when the resolved location differs' {
            { Add-SystemPathLocation -Location '%SystemRoot%\EasypeasyNoSuchFolder' -User } |
                Should -Throw "*location: '%SystemRoot%\EasypeasyNoSuchFolder', resolved: '$env:SystemRoot\EasypeasyNoSuchFolder'"
        }

        It 'names the location once when it is already normalized' {
            { Add-SystemPathLocation -Location 'C:\EasypeasyNoSuchFolder' -User } |
                Should -Throw "*location: 'C:\EasypeasyNoSuchFolder'"
        }

        It 'adds an existing folder' {
            Add-SystemPathLocation -Location $env:SystemRoot -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].StoredValue -eq $env:SystemRoot }
        }

        It 'adds a %...% reference that resolves to an existing folder' {
            Add-SystemPathLocation -Location '%SystemRoot%\system32' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].StoredValue -eq '%SystemRoot%\system32' }
        }

        It 'adds a missing folder with -Force' {
            Add-SystemPathLocation -Location $missing -User -Force

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].StoredValue -eq $script:missing }
        }

        It 'stores an unresolved %...% reference unexpanded with -Force' {
            Add-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' -User -Force -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].StoredValue -eq '%EASYPEASY_UNSET_XYZ%\bin' }
        }

        It 'does not create the missing folder with -Force' {
            Add-SystemPathLocation -Location $missing -User -Force

            $missing | Should -Not -Exist
        }
    }

    Context 'a location the other scope already carries' {

        # the real Set-SystemPath runs against scopes held in memory, so the process Path it rebuilds
        # reflects the write, the way it would against the registry
        BeforeEach {
            $script:originalPath = $env:PATH
            $script:machinePath = 'C:\Windows\System32'
            $script:userPath = 'C:\U1'

            Mock -ModuleName easypeasy Backup-SystemPath { }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { $script:machinePath }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { $script:userPath }
            Mock -ModuleName easypeasy Set-EnvironmentVariable {
                if ($Machine) { $script:machinePath = $Value } else { $script:userPath = $Value }
            }

            $env:PATH = 'C:\Windows\System32;C:\U1'
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists it in its own scope, keeping the reference' {
            Add-SystemPathLocation -Location '%windir%\system32' -User

            $script:userPath | Should -Be 'C:\U1;%windir%\system32'
        }

        It 'leaves the other scope alone' {
            Add-SystemPathLocation -Location '%windir%\system32' -User

            $script:machinePath | Should -Be 'C:\Windows\System32'
        }

        It 'lists it on the process Path once per scope, as Windows does' {
            Add-SystemPathLocation -Location '%windir%\system32' -User

            @($env:PATH -split ([IO.Path]::PathSeparator) |
                Where-Object { $_.TrimEnd('\') -ieq "$env:windir\system32" }).Count |
                Should -Be 2
        }
    }
}
