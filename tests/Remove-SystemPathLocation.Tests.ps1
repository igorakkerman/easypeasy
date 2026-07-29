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
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old' -and $User }
        }

        It 'takes the location positionally' {
            Remove-SystemPathLocation 'C:\Gone' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old' }
        }

        It 'does not persist under -WhatIf' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'holds a UNC root apart from a single leading backslash' {
            $script:currentEntries = New-PathEntries 'C:\Old;\\server\share'

            Remove-SystemPathLocation -Location '\server\share' -User -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match 'not on the system Path'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'removes an entry stored with repeated backslashes' {
            $script:currentEntries = New-PathEntries 'C:\Old;C:\Gone\\bin'

            Remove-SystemPathLocation -Location 'C:\Gone\bin' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old' }
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
            $script:currentEntries = @(New-PathEntry -StoredValue '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32') +
                @(New-PathEntries 'C:\Keep')
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'removes an entry given its expanded location' {
            Remove-SystemPathLocation -Location 'C:\WINDOWS\S32' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Keep' }
        }

        It 'removes an entry given its stored %...% form' {
            Remove-SystemPathLocation -Location '%SystemRoot%\S32' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Keep' }
        }

        It 'keeps the stored form of the remaining entries' {
            Remove-SystemPathLocation -Location 'C:\Keep' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq '%SystemRoot%\S32' }
        }
    }

    Context 'a location the other scope also carries' {

        # the real Set-SystemPath runs against scopes held in memory, so the process Path it rebuilds
        # reflects the write; the user scope loses the location, the machine scope keeps it
        BeforeEach {
            $script:originalPath = $env:PATH
            $script:machinePath = 'C:\Shared;C:\M1'
            $script:userPath = 'C:\Shared;C:\U1'

            Mock -ModuleName easypeasy Backup-SystemPath { }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { $script:machinePath }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { $script:userPath }
            Mock -ModuleName easypeasy Set-EnvironmentVariable {
                if ($Machine) { $script:machinePath = $Value } else { $script:userPath = $Value }
            }

            $env:PATH = 'C:\Shared;C:\M1;C:\Shared;C:\U1'
        }

        AfterEach { $env:PATH = $originalPath }

        It 'removes it from its own scope only' {
            Remove-SystemPathLocation -Location 'C:\Shared' -User

            $script:userPath | Should -Be 'C:\U1'
            $script:machinePath | Should -Be 'C:\Shared;C:\M1'
        }

        It 'leaves it on the process Path, the machine scope still carrying it' {
            Remove-SystemPathLocation -Location 'C:\Shared' -User

            $env:PATH -split ([IO.Path]::PathSeparator) | Should -Contain 'C:\Shared'
        }

        It 'lists it once, the duplicate contribution being gone' {
            Remove-SystemPathLocation -Location 'C:\Shared' -User

            @($env:PATH -split ([IO.Path]::PathSeparator) | Where-Object { $_ -eq 'C:\Shared' }).Count |
                Should -Be 1
        }
    }
}
