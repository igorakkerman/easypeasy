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

        It 'takes the name literally, so a wildcard matches nothing' {
            $env:EASYPEASY_TEST = 'hello'

            { Get-EnvironmentVariable 'EASYPEASY_TES?' -ErrorAction Stop } | Should -Throw '*not found*'
            { Get-EnvironmentVariable 'EASYPEASY_*' -ErrorAction Stop } | Should -Throw '*not found*'
        }

        It 'reads a variable whose name carries wildcard characters' {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST[1]', 'bracketed')
            try {
                Get-EnvironmentVariable 'EASYPEASY_TEST[1]' | Should -Be 'bracketed'
            }
            finally {
                [Environment]::SetEnvironmentVariable('EASYPEASY_TEST[1]', $null)
            }
        }
    }

    Context 'machine scope' {

        It 'reads a well-known machine variable' {
            Get-EnvironmentVariable windir -Machine | Should -Not -BeNullOrEmpty
        }
    }

    Context '-Expandable (unexpanded value)' {

        BeforeEach {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -User -Expandable
        }

        AfterEach {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', $null, 'User')
            Remove-Item -Path env:EASYPEASY_TEST -ErrorAction SilentlyContinue
        }

        It 'returns the stored %...% reference unevaluated' {
            Get-EnvironmentVariable EASYPEASY_TEST -User -Expandable | Should -Be '%SystemRoot%\tools'
        }

        It 'expands the reference without -Expandable' {
            Get-EnvironmentVariable EASYPEASY_TEST -User | Should -Be "$env:SystemRoot\tools"
        }

        It 'returns the effective value unevaluated, user over machine' {
            Get-EnvironmentVariable EASYPEASY_TEST -Expandable | Should -Be '%SystemRoot%\tools'
        }

        It 'errors when the variable is not set' {
            { Get-EnvironmentVariable EASYPEASY_MISSING_XYZ -Expandable -ErrorAction Stop } |
                Should -Throw '*not found*'
        }
    }
}
