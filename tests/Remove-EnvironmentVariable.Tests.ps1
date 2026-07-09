BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Remove-EnvironmentVariable' {

    Context 'user scope' {

        BeforeEach { [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', 'x', 'User') }
        AfterEach { [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', $null, 'User') }

        It 'removes a user environment variable' {
            Remove-EnvironmentVariable -Name EASYPEASY_TEST -User
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
        }

        It 'keeps the variable under -WhatIf' {
            Remove-EnvironmentVariable -Name EASYPEASY_TEST -User -WhatIf
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -Be 'x'
        }
    }

    Context 'machine scope requires administrator' {

        It 'errors when not elevated' {
            Mock -ModuleName easypeasy Assert-Administrator { throw 'admin required' }

            { Remove-EnvironmentVariable -Name EASYPEASY_TEST -ErrorAction Stop } |
                Should -Throw '*machine environment variable*'
        }
    }
}
