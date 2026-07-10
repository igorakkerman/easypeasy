BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-SystemPath' {

    Context 'effective path (default)' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns one SystemPathLocation per entry' {
            $env:PATH = 'C:\A;C:\B'

            $result = Get-SystemPath

            $result.Location | Should -Be @('C:\A', 'C:\B')
            $result[0].GetType().Name | Should -Be 'SystemPathLocation'
        }

        It 'skips empty entries such as a trailing semicolon' {
            $env:PATH = 'C:\A;;C:\B;'

            (Get-SystemPath).Location | Should -Be @('C:\A', 'C:\B')
        }

        It 'returns the raw string when -Join is used' {
            $env:PATH = 'C:\A;C:\B'

            Get-SystemPath -Join | Should -Be 'C:\A;C:\B'
        }
    }

    Context '-Filter' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns only locations matching the wildcard' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin;C:\Users\me\bin'

            (Get-SystemPath -Filter '*\Git\*').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'accepts the filter positionally' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'

            (Get-SystemPath '*Git*').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'

            (Get-SystemPath -Filter '*git*').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'ignores trailing backslashes on both sides' {
            $env:PATH = 'C:\Tools\'

            (Get-SystemPath -Filter 'C:\Tools').Location | Should -Be @('C:\Tools\')
        }

        It 'returns the matches joined when -Join is used' {
            $env:PATH = 'C:\A;C:\B;C:\Bin'

            Get-SystemPath -Filter 'C:\B*' -Join | Should -Be 'C:\B;C:\Bin'
        }

        It 'returns nothing when no location matches' {
            $env:PATH = 'C:\A;C:\B'

            Get-SystemPath -Filter '*nomatch*' | Should -BeNullOrEmpty
        }
    }

    Context 'machine and user scopes read the Path environment variable' {

        It 'reads the machine Path via Get-EnvironmentVariable' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Windows;C:\Windows\System32' }

            (Get-SystemPath -Machine).Location |
                Should -Be @('C:\Windows', 'C:\Windows\System32')

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Name -eq 'Path' }
        }

        It 'reads the user Path and honors -Join' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

            Get-SystemPath -User -Join | Should -Be 'C:\Users\me\bin'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }
    }
}
