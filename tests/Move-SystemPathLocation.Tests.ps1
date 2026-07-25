BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Move-SystemPathLocation' {

    BeforeEach {
        $script:originalPath = $env:PATH
        Mock -ModuleName easypeasy Set-SystemPath { }
    }

    AfterEach { $env:PATH = $originalPath }

    Context 'moving from machine to user (-ToUser)' {

        BeforeEach {
            $script:machineEntries = New-PathEntries 'C:\A;C:\X' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'removes from the machine Path and adds to the user Path' {
            Move-SystemPathLocation 'C:\X' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\B;C:\X' }
        }

        It 'does not persist under -WhatIf' {
            Move-SystemPathLocation 'C:\X' -ToUser -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'moving from user to machine (-ToMachine)' {

        BeforeEach {
            $script:userEntries = New-PathEntries 'C:\B;C:\X'
            $script:machineEntries = New-PathEntries 'C:\A' -Scope Machine
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
        }

        It 'removes from the user Path and adds to the machine Path' {
            Move-SystemPathLocation 'C:\X' -ToMachine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A;C:\X' }
        }
    }

    Context 'when the location is on both scopes' {

        BeforeEach {
            $script:machineEntries = New-PathEntries 'C:\A;C:\X' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\X'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'removes from the source and leaves the target unchanged' {
            Move-SystemPathLocation 'C:\X' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }
    }

    Context 'when the location is not on the source' {

        It 'warns and does not persist when already on the target' {
            $script:machineEntries = New-PathEntries 'C:\A' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\X'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Move-SystemPathLocation 'C:\X' -ToUser -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'already on the user Path'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'warns and does not persist when the location is on neither Path' {
            $script:machineEntries = New-PathEntries 'C:\A' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Move-SystemPathLocation 'C:\Z' -ToUser -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'not on the machine Path'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'expandable locations' {

        BeforeEach {
            $script:machineEntries = @(New-PathEntries 'C:\A' -Scope Machine) +
                @(New-PathEntry -ExpandableLocation '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32' -Scope Machine)
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'keeps the stored %...% form on the target Path' {
            Move-SystemPathLocation 'C:\WINDOWS\S32' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\B;%SystemRoot%\S32' }
        }

        It 'removes the entry from the source Path' {
            Move-SystemPathLocation 'C:\WINDOWS\S32' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\A' }
        }

        It 'accepts the stored %...% form as the location to move' {
            Move-SystemPathLocation '%SystemRoot%\S32' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\B;%SystemRoot%\S32' }
        }
    }
}
