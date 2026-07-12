BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Move-SystemPathLocation' {

    BeforeEach {
        $script:originalPath = $env:PATH
        Mock -ModuleName easypeasy Set-SystemPath { }
    }

    AfterEach { $env:PATH = $originalPath }

    Context 'moving from machine to user (-ToUser)' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A;C:\X' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\B' }
        }

        It 'removes from the machine path and adds to the user path' {
            Move-SystemPathLocation 'C:\X' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Path -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and $Path -eq 'C:\B;C:\X' }
        }

        It 'does not persist under -WhatIf' {
            Move-SystemPathLocation 'C:\X' -ToUser -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'moving from user to machine (-ToMachine)' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\B;C:\X' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A' }
        }

        It 'removes from the user path and adds to the machine path' {
            Move-SystemPathLocation 'C:\X' -ToMachine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and $Path -eq 'C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Path -eq 'C:\A;C:\X' }
        }
    }

    Context 'when the location is on both scopes' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A;C:\X' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\X' }
        }

        It 'removes from the source and leaves the target unchanged' {
            Move-SystemPathLocation 'C:\X' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Path -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }
    }

    Context 'when the location is not on the source' {

        It 'warns and does not persist when already on the target' {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\X' }

            Move-SystemPathLocation 'C:\X' -ToUser -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'already on the user path'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'warns and does not persist when the location is on neither path' {
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { 'C:\A' }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { 'C:\B' }

            Move-SystemPathLocation 'C:\Z' -ToUser -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'not on the machine path'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }
}
