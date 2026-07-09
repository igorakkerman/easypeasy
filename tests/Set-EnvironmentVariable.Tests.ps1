BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Set-EnvironmentVariable' {

    Context 'user scope' {

        AfterEach { [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', $null, 'User') }

        It 'sets a user environment variable' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -User
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -Be '42'
        }

        It 'does not set the variable under -WhatIf' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -User -WhatIf
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
        }
    }

    Context 'machine scope requires administrator' {

        It 'errors when not elevated' {
            Mock -ModuleName easypeasy Assert-Administrator { throw 'admin required' }

            { Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -ErrorAction Stop } |
                Should -Throw '*machine environment variable*'
        }
    }
}
