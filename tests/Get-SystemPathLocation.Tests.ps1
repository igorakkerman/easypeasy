BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-SystemPathLocation' {

    Context 'effective path (default)' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        BeforeEach {
            # persisted scopes are mocked so each location's origin scope is deterministic
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Windows' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Program Files\Git\bin' }
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'
        }

        It 'reports the origin scope of the matched location' {
            (Get-SystemPathLocation -Location 'C:\Windows').Scope | Should -Be 'Machine'
            (Get-SystemPathLocation -Location 'C:\Program Files\Git\bin').Scope | Should -Be 'User'
        }

        It 'reports Process scope for a session-only location' {
            $env:PATH = 'C:\Temp\session'

            $result = Get-SystemPathLocation -Location 'C:\Temp\session'

            $result.Location | Should -Be 'C:\Temp\session'
            $result.Scope | Should -Be 'Process'
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            (Get-SystemPathLocation -Location 'c:\windows\').Location | Should -Be 'C:\Windows'
        }

        It 'returns nothing when the location is absent' {
            Get-SystemPathLocation -Location 'C:\Nope' | Should -Be $null
        }

        It 'matches only the exact location, not a location containing it' {
            $env:PATH = 'C:\Windows;C:\Windows\System32'

            (Get-SystemPathLocation -Location 'C:\Windows').Location | Should -Be 'C:\Windows'
        }

        It 'matches a substring positionally' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin;C:\Here\Git'

            (Get-SystemPathLocation Git).Location |
                Should -Be @('C:\Program Files\Git\bin', 'C:\Here\Git')
        }

        It 'matches a wildcard via -Filter' {
            (Get-SystemPathLocation -Filter '*\Git\*').Location |
                Should -Be 'C:\Program Files\Git\bin'
        }

        It 'returns every location when the -Filter matches multiple' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Windows;C:\Git\cmd'

            (Get-SystemPathLocation -Filter '*Git*').Location |
                Should -Be @('C:\Program Files\Git\bin', 'C:\Git\cmd')
        }

        It 'matches a regex via -Match' {
            (Get-SystemPathLocation -Match '\\Git\\bin$').Location |
                Should -Be 'C:\Program Files\Git\bin'
        }

        It 'requires all criteria to be satisfied' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd'

            (Get-SystemPathLocation Git -Filter '*\bin').Location |
                Should -Be 'C:\Program Files\Git\bin'
        }

        It 'errors when no criterion is given' {
            { Get-SystemPathLocation -ErrorAction Stop } |
                Should -Throw '*at least one*'
        }
    }

    Context 'scoped lookups' {

        It 'reports Machine scope and reads the machine path' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Windows;C:\Tools' }

            $result = Get-SystemPathLocation -Location 'C:\Tools' -Machine

            $result.Scope | Should -Be 'Machine'
            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine }
        }

        It 'reports User scope and reads the user path' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

            (Get-SystemPathLocation -Location 'C:\Users\me\bin' -User).Scope | Should -Be 'User'
            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }

        It 'rejects both -Machine and -User' {
            { Get-SystemPathLocation -Location 'C:\x' -Machine -User } |
                Should -Throw '*only one*'
        }
    }
}
