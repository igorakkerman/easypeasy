BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Remove-DuplicateSystemPathLocations' {

    BeforeEach {
        $script:originalPath = $env:PATH
        Mock -ModuleName easypeasy Set-SystemPath { }
        # the in-process writes; the unelevated re-invocation has its own context
        Mock -ModuleName easypeasy Test-Elevated { $true }
    }

    AfterEach { $env:PATH = $originalPath }

    Context 'both scopes (default)' {

        BeforeEach {
            $script:machineEntries = New-PathEntries 'C:\A;C:\B;C:\A' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B;C:\C;C:\C'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'dedups each scope and keeps cross-scope duplicates on the machine Path by default' {
            Remove-DuplicateSystemPathLocations

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A;C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\C' }
        }

        It 'keeps cross-scope duplicates on the user Path with -KeepUser' {
            Remove-DuplicateSystemPathLocations -KeepUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\C' }
        }

        It 'does not persist under -WhatIf' {
            Remove-DuplicateSystemPathLocations -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'rejects both -KeepMachine and -KeepUser' {
            $errorRecord = { Remove-DuplicateSystemPathLocations -KeepMachine -KeepUser -ErrorAction Stop } |
                Should -Throw '*only one*' -PassThru

            $errorRecord.CategoryInfo.Category | Should -Be 'InvalidArgument'
            $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ConflictingKeepScope,*'
        }

        It 'rejects a -Keep switch together with a single scope' {
            { Remove-DuplicateSystemPathLocations -Machine -KeepUser } |
                Should -Throw '*Parameter set cannot be resolved*'
        }
    }

    Context 'idempotent when there are no duplicates' {

        BeforeEach {
            $script:machineEntries = New-PathEntries 'C:\A;C:\B' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\C;C:\D'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'does not persist when nothing changes' {
            Remove-DuplicateSystemPathLocations
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'single scope' {

        It 'dedups only the machine Path with -Machine' {
            $script:machineEntries = New-PathEntries 'C:\A;C:\B;C:\A' -Scope Machine
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }

            Remove-DuplicateSystemPathLocations -Machine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A;C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            $script:userEntries = New-PathEntries 'C:\A;C:\a\;C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A;C:\B' }
        }

        It 'holds a UNC root apart from a single leading backslash' {
            $script:userEntries = New-PathEntries '\\server\share;\server\share'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'ignores repeated backslashes' {
            $script:userEntries = New-PathEntries 'C:\A\bin;C:\A\\bin;C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A\bin;C:\B' }
        }

        It 'treats a reference whose variable is not set as a duplicate of itself' {
            $script:userEntries = New-PathEntries '%EASYPEASY_UNSET_XYZ%\bin;%EASYPEASY_UNSET_XYZ%\\bin\;C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq '%EASYPEASY_UNSET_XYZ%\bin;C:\B' }
        }

        It 'keeps two references naming different variables' {
            $script:userEntries = New-PathEntries '%EASYPEASY_UNSET_XYZ%\bin;%EASYPEASY_UNSET_ABC%\bin'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'when not elevated' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy Assert-SudoAvailable { }
            Mock -ModuleName easypeasy Get-ProcessOnlyPathLocations { @{} }
            Mock -ModuleName easypeasy Sync-ProcessPath { }

            $script:machineEntries = New-PathEntries 'C:\A;C:\B;C:\A' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B;C:\C;C:\C'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'runs the whole cleanup elevated once, writing neither Path in-process' {
            Remove-DuplicateSystemPathLocations

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'Remove-DuplicateSystemPathLocations' -and
                $Command -contains '-KeepMachine'
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'passes -KeepUser through to the elevated session' {
            Remove-DuplicateSystemPathLocations -KeepUser

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains '-KeepUser'
            }
        }

        It 'elevates for a single machine scope' {
            Remove-DuplicateSystemPathLocations -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains '-Machine'
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'syncs the current process Path after the elevated cleanup' {
            Remove-DuplicateSystemPathLocations

            Should -Invoke -ModuleName easypeasy Sync-ProcessPath -Times 1 -Exactly
        }

        It 'does not elevate for a user-only cleanup' {
            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\C' }
        }

        It 'does not elevate when the machine Path does not change' {
            $script:machineEntries = New-PathEntries 'C:\A' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\C;C:\C'

            Remove-DuplicateSystemPathLocations

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\C' }
        }

        It 'does not elevate under -WhatIf' {
            Remove-DuplicateSystemPathLocations -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'fails before any Path is written when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Remove-DuplicateSystemPathLocations } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'fails for -Machine before the Path is read when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Remove-DuplicateSystemPathLocations -Machine } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Get-SystemPath -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }

        It 'does not check sudo for a user-only cleanup' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Remove-DuplicateSystemPathLocations -User } | Should -Not -Throw
        }
    }

    Context 'expandable locations' {

        It 'treats a %...% entry and its expanded twin as duplicates, keeping the first' {
            $script:userEntries = @(New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32') +
                @(New-PathEntries 'C:\WINDOWS\S32;C:\B')
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq '%SystemRoot%\S32;C:\B' }
        }
    }
}
