BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Remove-DuplicateSystemPathLocations' {

    BeforeEach {
        $script:originalPath = $env:PATH
        Mock -ModuleName easypeasy Set-SystemPath { }
    }

    AfterEach { $env:PATH = $originalPath }

    Context 'both scopes (default)' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A;C:\B;C:\A' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\B;C:\C;C:\C' }
        }

        It 'dedups each scope and keeps cross-scope duplicates on the machine path by default' {
            Remove-DuplicateSystemPathLocations

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Path -eq 'C:\A;C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and $Path -eq 'C:\C' }
        }

        It 'keeps cross-scope duplicates on the user path with -KeepUser' {
            Remove-DuplicateSystemPathLocations -KeepUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Path -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and $Path -eq 'C:\B;C:\C' }
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
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A;C:\B' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\C;C:\D' }
        }

        It 'does not persist when nothing changes' {
            Remove-DuplicateSystemPathLocations
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'single scope' {

        It 'dedups only the machine path with -Machine' {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A;C:\B;C:\A' }

            Remove-DuplicateSystemPathLocations -Machine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Path -eq 'C:\A;C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\A;C:\a\;C:\B' }

            Remove-DuplicateSystemPathLocations -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and $Path -eq 'C:\A;C:\B' }
        }
    }
}
