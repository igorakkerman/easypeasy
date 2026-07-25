BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Sync-ProcessPath' {

    BeforeAll { $script:originalPath = $env:PATH }
    AfterAll { $env:PATH = $script:originalPath }

    Context 'deriving from the persisted scopes' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\M1;C:\M2' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\U1' }
        }

        It 'puts the machine Path before the user Path' {
            $env:PATH = 'C:\Stale'

            InModuleScope easypeasy { Sync-ProcessPath }

            $env:PATH | Should -Be 'C:\M1;C:\M2;C:\U1'
        }

        It 'ignores what the process Path held before' {
            $env:PATH = 'C:\Gone;C:\AlsoGone'

            InModuleScope easypeasy { Sync-ProcessPath }

            $env:PATH | Should -Not -Match 'Gone'
        }
    }

    Context 'expandable locations' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Windows\System32' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '%windir%\system32' }
        }

        It 'expands a %...% location, as a process Path holds it' {
            $env:PATH = 'C:\Stale'

            InModuleScope easypeasy { Sync-ProcessPath }

            $env:PATH | Should -Not -Match '%'
            $env:PATH | Should -Be "C:\Windows\System32;$env:windir\system32"
        }

        It 'keeps a location contributed by both scopes twice, as Windows leaves it' {
            $env:PATH = 'C:\Stale'

            InModuleScope easypeasy { Sync-ProcessPath }

            @($env:PATH -split ([IO.Path]::PathSeparator) |
                Where-Object { $_.TrimEnd('\') -ieq "$env:windir\system32" }).Count |
                Should -Be 2
        }
    }

    Context 'locations only the session knows' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\M1' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\U1' }
        }

        It 'keeps leading locations in front, preserving their precedence' {
            $leading = New-PathEntries 'C:\HostDir' -Scope Process
            $env:PATH = 'C:\Stale'

            InModuleScope easypeasy -Parameters @{ lead = $leading } {
                Sync-ProcessPath -LeadingProcessLocations $lead
            }

            $env:PATH | Should -Be 'C:\HostDir;C:\M1;C:\U1'
        }

        It 'keeps trailing locations behind the persisted ones' {
            $trailing = New-PathEntries 'C:\Venv' -Scope Process
            $env:PATH = 'C:\Stale'

            InModuleScope easypeasy -Parameters @{ trail = $trailing } {
                Sync-ProcessPath -TrailingProcessLocations $trail
            }

            $env:PATH | Should -Be 'C:\M1;C:\U1;C:\Venv'
        }

        It 'drops them when none are passed' {
            $env:PATH = 'C:\HostDir;C:\M1;C:\U1'

            InModuleScope easypeasy { Sync-ProcessPath }

            $env:PATH | Should -Be 'C:\M1;C:\U1'
        }
    }
}

Describe 'Get-ProcessOnlyPathLocations' {

    BeforeAll { $script:originalPath = $env:PATH }
    AfterAll { $env:PATH = $script:originalPath }

    BeforeEach {
        Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\M1' }
        Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\U1' }
    }

    It 'reports a location in front of the persisted ones as leading' {
        $env:PATH = 'C:\HostDir;C:\M1;C:\U1'

        $result = InModuleScope easypeasy { Get-ProcessOnlyPathLocations }

        $result.LeadingProcessLocations.Location | Should -Be 'C:\HostDir'
        $result.TrailingProcessLocations | Should -BeNullOrEmpty
    }

    It 'reports a location behind the persisted ones as trailing' {
        $env:PATH = 'C:\M1;C:\U1;C:\Venv'

        $result = InModuleScope easypeasy { Get-ProcessOnlyPathLocations }

        $result.LeadingProcessLocations | Should -BeNullOrEmpty
        $result.TrailingProcessLocations.Location | Should -Be 'C:\Venv'
    }

    It 'reports nothing when every location comes from a scope' {
        $env:PATH = 'C:\M1;C:\U1'

        $result = InModuleScope easypeasy { Get-ProcessOnlyPathLocations }

        $result.LeadingProcessLocations | Should -BeNullOrEmpty
        $result.TrailingProcessLocations | Should -BeNullOrEmpty
    }
}
