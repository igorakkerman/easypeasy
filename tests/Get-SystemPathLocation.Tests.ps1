BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-SystemPathLocation' {

    Context 'effective path (default)' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }
        BeforeEach { $env:PATH = 'C:\Windows;C:\Program Files\Git\bin' }

        It 'returns the matching location with Effective scope' {
            $result = Get-SystemPathLocation 'C:\Program Files\Git\bin'

            $result.Location | Should -Be 'C:\Program Files\Git\bin'
            $result.Scope | Should -Be 'Effective'
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            (Get-SystemPathLocation 'c:\windows\').Location | Should -Be 'C:\Windows'
        }

        It 'returns nothing when the location is absent' {
            Get-SystemPathLocation 'C:\Nope' | Should -Be $null
        }

        It 'matches a wildcard via -Filter' {
            (Get-SystemPathLocation -Filter '*\Git\*').Location |
                Should -Be 'C:\Program Files\Git\bin'
        }

        It 'returns every location when the -Filter matches multiple' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Windows;C:\Git\cmd'

            $result = Get-SystemPathLocation -Filter '*Git*'

            $result.Location | Should -Be @('C:\Program Files\Git\bin', 'C:\Git\cmd')
            $result.Scope | Should -Be @('Effective', 'Effective')
        }
    }

    Context 'scoped lookups' {

        It 'reports Machine scope and reads the machine path' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Windows;C:\Tools' }

            $result = Get-SystemPathLocation 'C:\Tools' -Machine

            $result.Scope | Should -Be 'Machine'
            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine }
        }

        It 'reports User scope and reads the user path' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

            (Get-SystemPathLocation 'C:\Users\me\bin' -User).Scope | Should -Be 'User'
            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }

        It 'rejects both -Machine and -User' {
            { Get-SystemPathLocation 'C:\x' -Machine -User } |
                Should -Throw '*only one*'
        }
    }
}
