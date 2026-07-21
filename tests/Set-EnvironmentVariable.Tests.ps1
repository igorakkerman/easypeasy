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

        It 'sets the variable in the user scope by default, without elevating' {
            Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }

            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42'

            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -Be '42'
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }
    }

    Context 'machine scope' {

        It 'auto-elevates instead of writing in-process when not administrator' {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }

            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -Machine

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'Set-EnvironmentVariable' -and
                $Command -contains 'EASYPEASY_TEST' -and
                $Command -contains '42' -and
                $Command -contains '-Machine'
            }
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'Machine') | Should -BeNullOrEmpty
        }

        It 'does not elevate under -WhatIf' {
            Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }

            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '42' -Machine -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }
    }

    Context 'expandable value (-Expand)' {

        AfterEach {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', $null, 'User')
            Remove-Item -Path env:EASYPEASY_TEST -ErrorAction SilentlyContinue
        }

        It 'writes a REG_EXPAND_SZ value with -Expand' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -User -Expand
            (Get-Item 'HKCU:\Environment').GetValueKind('EASYPEASY_TEST') |
                Should -Be ([Microsoft.Win32.RegistryValueKind]::ExpandString)
        }

        It 'stores the %...% reference verbatim, unexpanded' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -User -Expand
            (Get-Item 'HKCU:\Environment').GetValue('EASYPEASY_TEST', $null, 'DoNotExpandEnvironmentNames') |
                Should -Be '%SystemRoot%\tools'
        }

        It 'writes a REG_SZ value without -Expand' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -User
            (Get-Item 'HKCU:\Environment').GetValueKind('EASYPEASY_TEST') |
                Should -Be ([Microsoft.Win32.RegistryValueKind]::String)
        }

        It 'applies the expanded value to the current process immediately' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -User -Expand
            $env:EASYPEASY_TEST | Should -Be "$env:SystemRoot\tools"
        }

        It 'does not write under -WhatIf' {
            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -User -Expand -WhatIf
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'User') | Should -BeNullOrEmpty
            $env:EASYPEASY_TEST | Should -BeNullOrEmpty
        }

        It 'auto-elevates through Invoke-Elevated, passing -Expand, for a machine write when not administrator' {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }

            Set-EnvironmentVariable -Name EASYPEASY_TEST -Value '%SystemRoot%\tools' -Machine -Expand

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'Set-EnvironmentVariable' -and
                $Command -contains 'EASYPEASY_TEST' -and
                $Command -contains '-Machine' -and
                $Command -contains '-Expand'
            }
            [Environment]::GetEnvironmentVariable('EASYPEASY_TEST', 'Machine') | Should -BeNullOrEmpty
        }
    }
}
