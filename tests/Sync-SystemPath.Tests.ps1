BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Sync-SystemPath' {

    BeforeAll { $script:originalPath = $env:PATH }
    AfterAll { $env:PATH = $script:originalPath }

    BeforeEach {
        Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\M1;C:\M2' }
        Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\U1' }
    }

    It 'picks up a location added to a scope elsewhere' {
        $env:PATH = 'C:\M1;C:\U1'

        Sync-SystemPath

        $env:PATH | Should -Be 'C:\M1;C:\M2;C:\U1'
    }

    It 'keeps a location removed from a scope elsewhere, taking it for one this shell added' {
        # no scope carries C:\Removed any more, which is what a location added by this shell looks like too
        $env:PATH = 'C:\M1;C:\M2;C:\U1;C:\Removed'

        Sync-SystemPath

        $env:PATH | Should -Be 'C:\M1;C:\M2;C:\U1;C:\Removed'
    }

    It 'keeps a location only this shell knows' {
        $env:PATH = 'C:\HostDir;C:\M1;C:\U1;C:\Venv'

        Sync-SystemPath

        $env:PATH | Should -Be 'C:\HostDir;C:\M1;C:\M2;C:\U1;C:\Venv'
    }

    It 'is idempotent' {
        $env:PATH = 'C:\M1;C:\U1'

        Sync-SystemPath
        $once = $env:PATH
        Sync-SystemPath

        $env:PATH | Should -Be $once
    }

    It 'does not change the Path under -WhatIf' {
        $env:PATH = 'C:\Stale'

        Sync-SystemPath -WhatIf

        $env:PATH | Should -Be 'C:\Stale'
    }

    It 'is exposed through the syncpath alias' {
        $env:PATH = 'C:\M1;C:\U1'

        syncpath

        $env:PATH | Should -Be 'C:\M1;C:\M2;C:\U1'
    }

    Context 'expandable locations' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Windows\System32' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '%windir%\system32' }
        }

        It 'restores a location the other scope also carries' {
            # the shell lost the user contribution, as an incremental update would have left it
            $env:PATH = 'C:\Windows\System32'

            Sync-SystemPath

            @($env:PATH -split ([IO.Path]::PathSeparator) |
                Where-Object { $_.TrimEnd('\') -ieq "$env:windir\system32" }).Count |
                Should -Be 2
        }

        It 'expands the reference' {
            $env:PATH = 'C:\Windows\System32'

            Sync-SystemPath

            $env:PATH | Should -Not -Match '%'
        }
    }
}
