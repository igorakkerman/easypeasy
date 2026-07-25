BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Remove-SystemPathLocation' {

    Context 'delegation' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old;C:\Gone'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the trimmed path via Set-SystemPath' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Old' -and $User }
        }

        It 'does not persist under -WhatIf' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'targets the user scope by default' {
            Remove-SystemPathLocation -Location 'C:\Gone'

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and -not $Machine }
        }

        It 'targets the machine scope with -Machine' {
            Remove-SystemPathLocation -Location 'C:\Gone' -Machine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and -not $User }
        }
    }

    Context 'idempotent when the location is absent' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Remove-PathLocation runs; the location is not present.
            $script:currentEntries = New-PathEntries 'C:\Other'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'does not throw, even with -ErrorAction Stop' {
            { Remove-SystemPathLocation -Location 'C:\Gone' -User -ErrorAction Stop } |
                Should -Not -Throw
        }

        It 'warns that the location is not present' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User -WarningVariable warning -WarningAction SilentlyContinue
            $warning | Should -Match 'not on the system Path'
        }

        It 'does not persist when the location is absent' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'expandable locations' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = @(New-PathEntry -ExpandableLocation '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32') +
                @(New-PathEntries 'C:\Keep')
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'removes an entry given its expanded location' {
            Remove-SystemPathLocation -Location 'C:\WINDOWS\S32' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Keep' }
        }

        It 'removes an entry given its stored %...% form' {
            Remove-SystemPathLocation -Location '%SystemRoot%\S32' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Keep' }
        }

        It 'keeps the stored form of the remaining entries' {
            Remove-SystemPathLocation -Location 'C:\Keep' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq '%SystemRoot%\S32' }
        }
    }
}
