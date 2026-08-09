BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Move-SystemPathLocation' {

    BeforeEach {
        $script:originalPath = $env:PATH
        Mock -ModuleName easypeasy Set-SystemPath { }
        # the in-process writes; the unelevated re-invocation has its own context
        Mock -ModuleName easypeasy Test-Elevated { $true }
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
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X' }
        }

        It 'takes the location positionally' {
            Move-SystemPathLocation 'C:\X' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X' }
        }

        It 'does not persist under -WhatIf' {
            Move-SystemPathLocation 'C:\X' -ToUser -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'moves an entry stored with repeated backslashes, keeping its stored form' {
            $script:machineEntries = New-PathEntries 'C:\A;C:\X\\bin' -Scope Machine

            Move-SystemPathLocation 'C:\X\bin' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X\\bin' }
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
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A;C:\X' }
        }

        It 'writes the target Path before the source Path' {
            $global:pathWrites = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName easypeasy Set-SystemPath { $global:pathWrites.Add($Machine ? 'machine' : 'user') }

            try {
                Move-SystemPathLocation 'C:\X' -ToMachine

                $global:pathWrites | Should -Be @('machine', 'user')
            }
            finally {
                Remove-Variable -Name pathWrites -Scope Global -ErrorAction SilentlyContinue
            }
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
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }

        It 'removes from the user Path and leaves the machine Path unchanged (-ToMachine)' {
            $script:userEntries = New-PathEntries 'C:\B;C:\X'

            Move-SystemPathLocation 'C:\X' -ToMachine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $Machine }
        }
    }

    Context 'a reference whose variable is not set' {

        BeforeEach {
            $script:machineEntries = New-PathEntries 'C:\A;%EASYPEASY_UNSET_XYZ%\bin' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'moves the entry, keeping the reference, and names the variable' {
            Move-SystemPathLocation '%EASYPEASY_UNSET_XYZ%\bin' -ToUser `
                -WarningVariable reported -WarningAction SilentlyContinue

            $reported | Should -BeLike '*name: EASYPEASY_UNSET_XYZ,*'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;%EASYPEASY_UNSET_XYZ%\bin' }
        }

        It 'warns when the target already carries the same reference' {
            $script:userEntries = New-PathEntries 'C:\B;%EASYPEASY_UNSET_XYZ%\bin'

            Move-SystemPathLocation '%EASYPEASY_UNSET_XYZ%\bin' -ToUser -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly `
                -ParameterFilter { $User }
        }
    }

    Context 'from the pipeline' {

        BeforeEach {
            $script:machineEntries = New-PathEntries 'C:\A;C:\X;C:\Y' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'takes a piped entry as the location it stores' {
            New-PathEntries 'C:\X' -Scope Machine | Move-SystemPathLocation -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X' }
        }

        It 'takes the entry passed on inside ForEach-Object' {
            New-PathEntries 'C:\X' -Scope Machine | ForEach-Object { Move-SystemPathLocation $_ -ToUser }

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X' }
        }

        It 'moves every piped location in a single write per scope' {
            'C:\X', 'C:\Y' | Move-SystemPathLocation -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X;C:\Y' }
        }

        It 'warns for the piped location that is not on the source Path, moving the others' {
            'C:\X', 'C:\Nowhere' | Move-SystemPathLocation -ToUser `
                -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -HaveCount 1
            $warning | Should -Match 'C:\\Nowhere'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;C:\X' }
        }

        It 'writes nothing under -WhatIf' {
            'C:\X', 'C:\Y' | Move-SystemPathLocation -ToUser -WhatIf

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'reads and writes nothing for an empty pipeline' {
            @() | Move-SystemPathLocation -ToUser

            Should -Invoke -ModuleName easypeasy Get-SystemPath -Times 0 -Exactly
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

            $script:machineEntries = New-PathEntries 'C:\A;C:\M' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B;C:\U'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'runs the whole move elevated, writing neither Path in-process (-ToMachine)' {
            Move-SystemPathLocation 'C:\U' -ToMachine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Move-SystemPathLocation' -and
                $Command -contains '-Location' -and
                $Command[2] -contains 'C:\U' -and
                $Command -contains '-ToMachine'
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'passes every piped location on to the one elevated session' {
            'C:\U', 'C:\B' | Move-SystemPathLocation -ToMachine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Move-SystemPathLocation' -and
                $Command[2] -contains 'C:\U' -and
                $Command[2] -contains 'C:\B' -and
                $Command -contains '-ToMachine'
            }
        }

        It 'runs the whole move elevated, writing neither Path in-process (-ToUser)' {
            Move-SystemPathLocation 'C:\M' -ToUser

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Move-SystemPathLocation' -and
                $Command -contains '-Location' -and
                $Command[2] -contains 'C:\M' -and
                $Command -contains '-ToUser'
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'syncs the current process Path after the elevated move' {
            Move-SystemPathLocation 'C:\U' -ToMachine

            Should -Invoke -ModuleName easypeasy Sync-ProcessPath -Times 1 -Exactly
        }

        It 'does not elevate when the machine Path does not change' {
            $script:machineEntries = New-PathEntries 'C:\A;C:\U' -Scope Machine

            Move-SystemPathLocation 'C:\U' -ToMachine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B' }
        }

        It 'does not elevate under -WhatIf' {
            Move-SystemPathLocation 'C:\U' -ToMachine -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'does not elevate when the location is not on the source Path' {
            Move-SystemPathLocation 'C:\Z' -ToMachine -WarningAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }

        It 'fails before any Path is written when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Move-SystemPathLocation 'C:\U' -ToMachine } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'does not check sudo when the machine Path does not change' {
            $script:machineEntries = New-PathEntries 'C:\A;C:\U' -Scope Machine
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Move-SystemPathLocation 'C:\U' -ToMachine } | Should -Not -Throw
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

        It 'holds a UNC root apart from a single leading backslash' {
            $script:machineEntries = New-PathEntries 'C:\A;\\server\share' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }

            Move-SystemPathLocation '\server\share' -ToUser -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'not on the machine Path'
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
                @(New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32' -Scope Machine)
            $script:userEntries = New-PathEntries 'C:\B'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
        }

        It 'keeps the stored %...% form on the target Path' {
            Move-SystemPathLocation 'C:\WINDOWS\S32' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;%SystemRoot%\S32' }
        }

        It 'removes the entry from the source Path' {
            Move-SystemPathLocation 'C:\WINDOWS\S32' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\A' }
        }

        It 'accepts the stored %...% form as the location to move' {
            Move-SystemPathLocation '%SystemRoot%\S32' -ToUser

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\B;%SystemRoot%\S32' }
        }
    }
}
