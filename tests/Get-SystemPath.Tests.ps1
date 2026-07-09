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
