BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Test-SystemPathLocation' {

    BeforeAll { $script:originalPath = $env:PATH }
    AfterAll { $env:PATH = $script:originalPath }
    BeforeEach { $env:PATH = 'C:\Windows;C:\Program Files\Git\bin' }

    It 'returns $true when the location is present' {
        Test-SystemPathLocation 'C:\Program Files\Git\bin' | Should -BeTrue
    }

    It 'returns $false when the location is absent' {
        Test-SystemPathLocation 'C:\Nope' | Should -BeFalse
    }

    It 'matches case-insensitively and ignores trailing backslashes' {
        Test-SystemPathLocation 'c:\windows\' | Should -BeTrue
    }

    It 'returns $true for a matching -Filter wildcard' {
        Test-SystemPathLocation -Filter '*\Git\*' | Should -BeTrue
    }

    It 'returns $false for a non-matching -Filter wildcard' {
        Test-SystemPathLocation -Filter '*\Nope\*' | Should -BeFalse
    }

    It 'honors the requested scope' {
        Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

        Test-SystemPathLocation 'C:\Users\me\bin' -User | Should -BeTrue
        Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User }
    }
}
