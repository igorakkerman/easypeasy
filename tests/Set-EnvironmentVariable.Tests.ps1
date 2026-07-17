BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Set-EnvironmentVariable' {

    Context 'user scope' {

        AfterEach {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', $null, 'User')
            Remove-Item -Path env:EASYPEASY_TEST -ErrorAction SilentlyContinue
        }

        It 'sets a user environment variable' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -User
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -Be '42'
        }

        It 'applies the change to the current process immediately' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -User
            $env:EASYPEASY_TEST | Should -Be '42'
        }

        It 'does not set the variable under -WhatIf' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -User -WhatIf
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
            $env:EASYPEASY_TEST | Should -BeNullOrEmpty
        }

        It 'sets the variable in the user scope by default, without requiring administrator' {
            Mock -ModuleName easypeasy Assert-Administrator { throw 'admin required' }

            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42'

            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -Be '42'
            Should -Invoke -ModuleName easypeasy Assert-Administrator -Times 0 -Exactly
        }
    }

    Context 'machine scope requires administrator' {

        It 'errors when not elevated' {
            Mock -ModuleName easypeasy Assert-Administrator { throw 'admin required' }

            { Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -Machine -ErrorAction Stop } |
                Should -Throw '*admin required*'
        }
    }
}
