BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Test-SystemPathLocation' {

    BeforeAll { $script:originalPath = $env:PATH }
    AfterAll { $env:PATH = $script:originalPath }
    BeforeEach { $env:PATH = 'C:\Windows;C:\Program Files\Git\bin' }

    It 'returns $true when the location is present' {
        Test-SystemPathLocation -Location 'C:\Program Files\Git\bin' | Should -BeTrue
    }

    It 'returns $false when the location is absent' {
        Test-SystemPathLocation -Location 'C:\Nope' | Should -BeFalse
    }

    It 'matches case-insensitively and ignores trailing backslashes' {
        Test-SystemPathLocation -Location 'c:\windows\' | Should -BeTrue
    }

    It 'returns $true for a contained substring given positionally' {
        Test-SystemPathLocation Git | Should -BeTrue
    }

    It 'returns $false for a substring no location contains' {
        Test-SystemPathLocation Nope | Should -BeFalse
    }

    It 'returns $true for a matching -Filter wildcard' {
        Test-SystemPathLocation -Filter '*\Git\*' | Should -BeTrue
    }

    It 'returns $false for a non-matching -Filter wildcard' {
        Test-SystemPathLocation -Filter '*\Nope\*' | Should -BeFalse
    }

    It 'returns $true for a matching -Match regex' {
        Test-SystemPathLocation -Match '\\Git\\bin$' | Should -BeTrue
    }

    It 'rejects an invalid -Match regex, reporting the pattern and the reason' {
        { Test-SystemPathLocation -Match '(' } |
            Should -Throw -ExpectedMessage "*'(' is not a valid regular expression: *Not enough*"
    }

    It 'returns $false when one of several criteria fails' {
        Test-SystemPathLocation Git -Filter '*\cmd' | Should -BeFalse
    }

    It 'errors when no criterion is given' {
        { Test-SystemPathLocation -ErrorAction Stop } | Should -Throw '*at least one*'
    }

    It 'honors the requested scope' {
        Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

        Test-SystemPathLocation -Location 'C:\Users\me\bin' -User | Should -BeTrue
        Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User }
    }
}
