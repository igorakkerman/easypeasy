BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Remove-DuplicateSystemPathLocations' {

    BeforeEach {
        $script:originalPath = $env:PATH
        Mock -ModuleName easypeasy Set-SystemPath { }
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
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A;C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\C' }
        }

        It 'keeps cross-scope duplicates on the user Path with -KeepUser' {
            Remove-DuplicateSystemPathLocations -KeepUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\B;C:\C' }
        }

        It 'does not persist under -WhatIf' {
            Remove-DuplicateSystemPathLocations -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'rejects both -KeepMachine and -KeepUser' {
            { Remove-DuplicateSystemPathLocations -KeepMachine -KeepUser -ErrorAction Stop } |
                Should -Throw '*only one*'
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
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A;C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            $script:userEntries = New-PathEntries 'C:\A;C:\a\;C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A;C:\B' }
        }
    }

    Context 'expandable locations' {

        It 'treats a %...% entry and its expanded twin as duplicates, keeping the first' {
            $script:userEntries = @(New-PathEntry -ExpandableLocation '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32') +
                @(New-PathEntries 'C:\WINDOWS\S32;C:\B')
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq '%SystemRoot%\S32;C:\B' }
        }
    }
}
