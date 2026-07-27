BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Add-SystemPathLocation' {

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
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Old;C:\New' -and $User }
        }

        It 'takes the location positionally' {
            Add-SystemPathLocation 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Old;C:\New' }
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
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Exists;C:\A;C:\B' -and $User }
        }

        It 'does not throw for an existing location' {
            { Add-SystemPathLocation -Location 'C:\Exists' -First -User -ErrorAction Stop } |
                Should -Not -Throw
        }

        It 'accepts the Front alias' {
            Add-SystemPathLocation -Location 'C:\Exists' -User -Front

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Exists;C:\A;C:\B' }
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
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq 'C:\Old;%SystemRoot%\Tools' }
        }

        It 'expands a %...% location into the entry Location' {
            $script:currentEntries = New-PathEntries 'C:\Old'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location '%SystemRoot%\Tools' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Entries[-1].Location -eq "$env:SystemRoot\Tools" }
        }

        It 'keeps an existing entry stored form when another location is added' {
            $script:currentEntries = New-PathEntry -ExpandableLocation '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.ExpandableLocation }) -join ';') -eq '%SystemRoot%\S32;C:\New' }
        }

        It 'recognizes an existing %...% entry by its expanded location' {
            $script:currentEntries = New-PathEntry -ExpandableLocation '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }

            Add-SystemPathLocation -Location 'C:\WINDOWS\S32' -User -WarningAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
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
