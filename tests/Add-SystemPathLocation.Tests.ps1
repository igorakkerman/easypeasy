BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Add-SystemPathLocation' {

    Context 'delegation' {

        BeforeEach {
            $script:originalPath = $env:PATH
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\Old' }
            Mock -ModuleName easypeasy Add-PathLocation { 'C:\Old;C:\New' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the extended path via Set-SystemPath' {
            Add-SystemPathLocation -Location 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Path -eq 'C:\Old;C:\New' -and $User }
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

    Context 'idempotent when the location is already present' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Add-PathLocation runs; the location is already present.
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\Exists' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'does not throw, even with -ErrorAction Stop' {
            { Add-SystemPathLocation -Location 'C:\Exists' -User -ErrorAction Stop } |
                Should -Not -Throw
        }

        It 'warns that the location is already present' {
            Add-SystemPathLocation -Location 'C:\Exists' -User -WarningVariable warning -WarningAction SilentlyContinue
            $warning | Should -Match 'already on the system path'
        }

        It 'does not persist when the location is already present' {
            Add-SystemPathLocation -Location 'C:\Exists' -User
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'moving an existing location to the front with -Front' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Add-PathLocation runs; the location is already present in the middle.
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\A;C:\Exists;C:\B' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the location moved to the front' {
            Add-SystemPathLocation -Location 'C:\Exists' -Front -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Path -eq 'C:\Exists;C:\A;C:\B' -and $User }
        }

        It 'does not throw for an existing location' {
            { Add-SystemPathLocation -Location 'C:\Exists' -Front -User -ErrorAction Stop } |
                Should -Not -Throw
        }
    }
}
