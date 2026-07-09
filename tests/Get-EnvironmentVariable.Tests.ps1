BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-EnvironmentVariable' {

    Context 'effective (current process)' {

        AfterEach { $env:EASYPEASY_TEST = $null }

        It 'returns the value of a process variable' {
            $env:EASYPEASY_TEST = 'hello'
            Get-EnvironmentVariable EASYPEASY_TEST | Should -Be 'hello'
        }

        It 'errors when the variable is not set' {
            { Get-EnvironmentVariable EASYPEASY_MISSING_XYZ -ErrorAction Stop } |
                Should -Throw '*not found*'
        }
    }

    Context 'machine scope' {

        It 'reads a well-known machine variable' {
            Get-EnvironmentVariable windir -Machine | Should -Not -BeNullOrEmpty
        }
    }
}
