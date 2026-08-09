BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Remove-SystemPathLocation' {

    BeforeEach {
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }
    }

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

    Context 'when not elevated' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old;C:\Gone'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy Assert-SudoAvailable { }
            Mock -ModuleName easypeasy Get-ProcessOnlyPathLocations { @{} }
            Mock -ModuleName easypeasy Sync-ProcessPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'runs the whole removal elevated for -Machine, passing no Path' {
            Remove-SystemPathLocation -Location 'C:\Gone' -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Remove-SystemPathLocation' -and
                $Command -contains '-Location' -and
                @($Command[2]).Count -eq 1 -and
                $Command[2] -contains 'C:\Gone' -and
                $Command -contains '-Machine' -and
                -not ($Command -join ' ').Contains('C:\Old')
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'passes every piped location on to the one elevated session' {
            'C:\Gone', 'C:\Old' | Remove-SystemPathLocation -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Remove-SystemPathLocation' -and
                $Command[2] -contains 'C:\Gone' -and
                $Command[2] -contains 'C:\Old' -and
                $Command -contains '-Machine'
            }
        }

        It 'does not elevate for the user scope' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly
        }

        It 'does not elevate under -WhatIf' {
            Remove-SystemPathLocation -Location 'C:\Gone' -Machine -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'does not elevate when the location is absent' {
            Remove-SystemPathLocation -Location 'C:\Missing' -Machine -WarningAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }

        It 'fails for -Machine before reading the Path when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Remove-SystemPathLocation -Location 'C:\Gone' -Machine } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Get-SystemPath -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'from the pipeline' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries 'C:\Old;C:\Gone;C:\Stale'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'takes a piped entry as the location it stores' {
            New-PathEntries 'C:\Gone' | Remove-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\Stale' }
        }

        It 'takes a piped entry whose reference resolves to nothing by that reference' {
            $script:currentEntries = New-PathEntries 'C:\Old;%EASYPEASY_UNSET_XYZ%\bin'

            New-PathEntries '%EASYPEASY_UNSET_XYZ%\bin' `
                | Remove-SystemPathLocation -User -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old' }
        }

        It 'takes a piped string' {
            'C:\Gone' | Remove-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\Stale' }
        }

        It 'takes the entry passed on inside ForEach-Object' {
            New-PathEntries 'C:\Gone' | ForEach-Object { Remove-SystemPathLocation $_ -User }

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old;C:\Stale' }
        }

        It 'removes every piped location in a single write' {
            New-PathEntries 'C:\Gone;C:\Stale' | Remove-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old' }
        }

        It 'removes every location given as an argument list' {
            Remove-SystemPathLocation -Location 'C:\Gone', 'C:\Stale' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Old' }
        }

        It 'warns for each piped location that is not present' {
            'C:\Missing', 'C:\Absent' | Remove-SystemPathLocation -User `
                -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -HaveCount 2
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'writes nothing under -WhatIf' {
            New-PathEntries 'C:\Gone;C:\Stale' | Remove-SystemPathLocation -User -WhatIf

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'reads and writes nothing for an empty pipeline' {
            @() | Remove-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Get-SystemPath -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'scope of a piped entry' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:machineEntries = New-PathEntries 'C:\EasypeasyKeep\bin;C:\EasypeasyTool\bin' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\EasypeasyMine\bin;C:\EasypeasyTool\bin'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'removes each entry from the scope it carries' {
            @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyMine\bin') `
                | Remove-SystemPathLocation

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\EasypeasyKeep\bin' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\EasypeasyTool\bin' }
        }

        It 'removes a location both scopes carry from both of them' {
            @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyTool\bin') `
                | Remove-SystemPathLocation

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\EasypeasyKeep\bin' }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\EasypeasyMine\bin' }
        }

        It 'removes only the user entries with -User' {
            @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyTool\bin') `
                | Remove-SystemPathLocation -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly -ParameterFilter { $Machine }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $User -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\EasypeasyMine\bin' }
        }

        It 'removes only the machine entries with -Machine' {
            @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyTool\bin') `
                | Remove-SystemPathLocation -Machine

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly -ParameterFilter { $User }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Machine -and (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\EasypeasyKeep\bin' }
        }

        It 'writes nothing and warns about nothing when the switch matches no entry' {
            New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine `
                | Remove-SystemPathLocation -User -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -HaveCount 0
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }

        It 'keeps the scope of an entry passed as -Entry inside ForEach-Object' {
            New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine `
                | ForEach-Object { Remove-SystemPathLocation -Entry $_ }

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly -ParameterFilter { $Machine }
        }

        It 'falls back to the user scope for an entry passed as $_ inside ForEach-Object' {
            New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine `
                | ForEach-Object { Remove-SystemPathLocation $_ }

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly -ParameterFilter { $User }
        }

        It 'does not persist under -WhatIf' {
            @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyMine\bin') `
                | Remove-SystemPathLocation -WhatIf

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'a piped entry of the process scope' {

        # the real Set-SystemPath and Sync-ProcessPath run against scopes held in memory, so the process
        # Path this shell ends up with is the one a real removal would leave
        BeforeEach {
            $script:originalPath = $env:PATH
            $script:machinePath = 'C:\EasypeasyM\bin'
            $script:userPath = 'C:\EasypeasyU\bin'

            Mock -ModuleName easypeasy Backup-SystemPath { }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { $script:machinePath }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { $script:userPath }
            Mock -ModuleName easypeasy Set-EnvironmentVariable {
                if ($Machine) { $script:machinePath = $Value } else { $script:userPath = $Value }
            }

            $env:PATH = 'C:\EasypeasyM\bin;C:\EasypeasyU\bin;C:\EasypeasyShell\bin'
        }

        AfterEach { $env:PATH = $originalPath }

        It 'drops it from the Path of the current shell' {
            Get-SystemPath -Contains EasypeasyShell | Remove-SystemPathLocation

            $env:PATH -split ([IO.Path]::PathSeparator) | Should -Not -Contain 'C:\EasypeasyShell\bin'
        }

        It 'leaves the persisted locations on the Path of the current shell' {
            Get-SystemPath -Contains EasypeasyShell | Remove-SystemPathLocation

            $env:PATH -split ([IO.Path]::PathSeparator) | Should -Contain 'C:\EasypeasyM\bin'
            $env:PATH -split ([IO.Path]::PathSeparator) | Should -Contain 'C:\EasypeasyU\bin'
        }

        It 'persists neither scope' {
            Get-SystemPath -Contains EasypeasyShell | Remove-SystemPathLocation

            Should -Invoke -ModuleName easypeasy Set-EnvironmentVariable -Times 0 -Exactly
            $script:machinePath | Should -Be 'C:\EasypeasyM\bin'
            $script:userPath | Should -Be 'C:\EasypeasyU\bin'
        }

        It 'leaves the shell Path alone under -WhatIf' {
            Get-SystemPath -Contains EasypeasyShell | Remove-SystemPathLocation -WhatIf

            $env:PATH -split ([IO.Path]::PathSeparator) | Should -Contain 'C:\EasypeasyShell\bin'
        }
    }

    Context 'a piped entry of the machine scope when not elevated' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:machineEntries = New-PathEntries 'C:\EasypeasyKeep\bin;C:\EasypeasyTool\bin' -Scope Machine
            $script:userEntries = New-PathEntries 'C:\EasypeasyMine\bin;C:\EasypeasyTool\bin'
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } { $script:machineEntries }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } { $script:userEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy Assert-SudoAvailable { }
            Mock -ModuleName easypeasy Get-ProcessOnlyPathLocations { @{} }
            Mock -ModuleName easypeasy Sync-ProcessPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'runs the machine part elevated and the user part in-process' {
            @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyMine\bin') `
                | Remove-SystemPathLocation

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command[0] -eq 'Remove-SystemPathLocation' -and
                @($Command[2]).Count -eq 1 -and
                $Command[2] -contains 'C:\EasypeasyTool\bin' -and
                $Command -contains '-Machine'
            }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly -ParameterFilter { $User }
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly -ParameterFilter { $Machine }
        }

        It 'does not elevate for a user entry alone' {
            New-PathEntries 'C:\EasypeasyMine\bin' | Remove-SystemPathLocation

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly -ParameterFilter { $User }
        }

        It 'writes neither scope when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { @(New-PathEntries 'C:\EasypeasyTool\bin' -Scope Machine) + @(New-PathEntries 'C:\EasypeasyMine\bin') `
                    | Remove-SystemPathLocation } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
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

    Context 'a reference whose variable is not set' {

        BeforeEach {
            $script:originalPath = $env:PATH
            $script:currentEntries = New-PathEntries '%EASYPEASY_UNSET_XYZ%\bin;C:\Keep'
            Mock -ModuleName easypeasy Get-SystemPath { $script:currentEntries }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'removes the entry given the reference, and names the variable' {
            Remove-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' -User `
                -ErrorVariable reported -ErrorAction SilentlyContinue

            $reported.FullyQualifiedErrorId | Should -BeLike 'EnvironmentVariableNotSet,*'
            $reported.TargetObject | Should -Be 'EASYPEASY_UNSET_XYZ'
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Keep' }
        }

        It 'ignores repeated and trailing backslashes on the reference' {
            Remove-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\\bin\' -User -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { (($Entries | ForEach-Object { $_.StoredValue }) -join ';') -eq 'C:\Keep' }
        }

        It 'leaves an entry carrying another reference alone' {
            Remove-SystemPathLocation -Location '%EASYPEASY_UNSET_ABC%\bin' -User `
                -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
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
