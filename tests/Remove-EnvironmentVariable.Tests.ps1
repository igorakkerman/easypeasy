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

        It 'removes the variable from the user scope by default, without elevating' {
            Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }

            Remove-EnvironmentVariable -Name EASYPEASY_TEST

            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }

        It 'warns when the variable is not set' {
            Remove-EnvironmentVariable -Name EASYPEASY_ABSENT -User -WarningVariable warning -WarningAction SilentlyContinue

            $warning | Should -Match "not set"
        }
    }

    Context 'machine scope' {

        It 'auto-elevates instead of writing in-process when not administrator' {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'present' }

            Remove-EnvironmentVariable -Name EASYPEASY_TEST -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'Remove-EnvironmentVariable' -and
                $Command -contains 'EASYPEASY_TEST' -and
                $Command -contains '-Machine'
            }
        }

        It 'does not elevate under -WhatIf' {
            Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'present' }

            Remove-EnvironmentVariable -Name EASYPEASY_TEST -Machine -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }
    }
}
