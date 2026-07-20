BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Remove-EnvironmentVariable' {

    Context 'user scope' {

        BeforeEach {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', 'x', 'User')
            $env:EASYPEASY_TEST = 'x'
        }
        AfterEach {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', [NullString]::Value, 'User')
            Remove-Item -Path env:EASYPEASY_TEST -ErrorAction SilentlyContinue
        }

        It 'removes a user environment variable' {
            Remove-EnvironmentVariable -Name EASYPEASY_TEST -User
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
        }

        It 'deletes the registry value instead of leaving an empty tombstone' {
            Remove-EnvironmentVariable -Name EASYPEASY_TEST -User
            (Get-Item 'HKCU:\Environment').GetValueNames() | Should -Not -Contain 'EASYPEASY_TEST'
        }

        It 'clears the variable from the current process immediately' {
            Remove-EnvironmentVariable -Name EASYPEASY_TEST -User
            $env:EASYPEASY_TEST | Should -BeNullOrEmpty
        }

        It 'keeps the variable under -WhatIf' {
            Remove-EnvironmentVariable -Name EASYPEASY_TEST -User -WhatIf
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -Be 'x'
            $env:EASYPEASY_TEST | Should -Be 'x'
        }

        It 'removes the variable from the user scope by default, without requiring administrator' {
            Mock -ModuleName easypeasy Assert-Administrator { throw 'admin required' }

            Remove-EnvironmentVariable -Name EASYPEASY_TEST

            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
            Should -Invoke -ModuleName easypeasy Assert-Administrator -Times 0 -Exactly
        }
    }

    Context 'machine scope requires administrator' {

        It 'errors when not elevated' {
            Mock -ModuleName easypeasy Assert-Administrator { throw 'admin required' }

            { Remove-EnvironmentVariable -Name EASYPEASY_TEST -Machine -ErrorAction Stop } |
                Should -Throw '*admin required*'
        }
    }
}
