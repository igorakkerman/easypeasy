BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-Environment' {

    Context 'user scope' {

        AfterEach {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', $null, 'User')
        }

        It 'returns a persisted user variable with its value and scope' {
            [Environment]::SetEnvironmentVariable('EASYPEASY_TEST', '42', 'User')

            $variable = Get-Environment -User | Where-Object { $_.Name -eq 'EASYPEASY_TEST' }

            $variable.Value | Should -Be '42'
            $variable.Scope | Should -Be 'User'
        }

        It 'tags every record with the User scope' {
            (Get-Environment -User).Scope | Should -Not -Contain 'Machine'
            (Get-Environment -User | ForEach-Object Scope | Sort-Object -Unique) | Should -Be 'User'
        }
    }

    Context 'machine scope' {

        It 'returns machine variables tagged with the Machine scope' {
            $variables = Get-Environment -Machine

            $variables | Should -Not -BeNullOrEmpty
            ($variables | ForEach-Object Scope | Sort-Object -Unique) | Should -Be 'Machine'
        }

        It 'includes the machine Path' {
            (Get-Environment -Machine | Where-Object { $_.Name -eq 'Path' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'scope is required' {

        It 'errors when neither -Machine nor -User is given' {
            { Get-Environment } | Should -Throw
        }
    }
}
