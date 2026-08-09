BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Test-SystemPathLocation' {

    BeforeAll { $script:originalPath = $env:PATH }
    AfterAll { $env:PATH = $script:originalPath }
    BeforeEach { $env:PATH = 'C:\EasypeasyRoot;C:\Easypeasy Files\Tool\bin' }

    It 'returns $true when the location is present' {
        Test-SystemPathLocation -Location 'C:\Easypeasy Files\Tool\bin' | Should -BeTrue
    }

    It 'returns $true for the location given positionally' {
        Test-SystemPathLocation 'C:\Easypeasy Files\Tool\bin' | Should -BeTrue
    }

    It 'returns $false when the location is absent' {
        Test-SystemPathLocation -Location 'C:\Nope' | Should -BeFalse
    }

    It 'matches case-insensitively and ignores trailing backslashes' {
        Test-SystemPathLocation -Location 'c:\easypeasyroot\' | Should -BeTrue
    }

    It 'ignores repeated backslashes in the location argument' {
        Test-SystemPathLocation -Location 'C:\Easypeasy Files\\Tool\bin' | Should -BeTrue
        Test-SystemPathLocation -Location 'C:\\\Easypeasy Files\Tool\\bin\\' | Should -BeTrue
    }

    It 'ignores repeated backslashes in the Path entry' {
        $env:PATH = 'C:\Easypeasy Files\\Tool\bin'

        Test-SystemPathLocation -Location 'C:\Easypeasy Files\Tool\bin' | Should -BeTrue
    }

    It 'returns $false for a substring of a location' {
        Test-SystemPathLocation Tool | Should -BeFalse
    }

    It 'returns $false for a wildcard pattern matching a location' {
        Test-SystemPathLocation '*\Tool\*' | Should -BeFalse
    }

    It 'requires the location' {
        { Test-SystemPathLocation } | Should -Throw '*Location*'
    }

    It 'finds a location carrying a reference whose variable is not set' {
        $env:PATH = '%EASYPEASY_UNSET_XYZ%\bin;C:\EasypeasyRoot'

        Test-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' -ErrorAction SilentlyContinue |
            Should -BeTrue
    }

    It 'names the variable that is not set' {
        $env:PATH = '%EASYPEASY_UNSET_XYZ%\bin;C:\EasypeasyRoot'

        Test-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' `
            -ErrorVariable reported -ErrorAction SilentlyContinue | Out-Null

        $reported.TargetObject | Should -Be 'EASYPEASY_UNSET_XYZ'
    }

    It 'is exposed through the testpath alias' {
        testpath 'C:\Easypeasy Files\Tool\bin' | Should -BeTrue
    }

    It 'searches only the process-only locations when -Process is given' {
        Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\EasypeasyRoot' }
        Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
        $env:PATH = 'C:\EasypeasyRoot;C:\EasypeasyTemp\session'

        Test-SystemPathLocation -Location 'C:\EasypeasyTemp\session' -Process | Should -BeTrue
        Test-SystemPathLocation -Location 'C:\EasypeasyRoot' -Process | Should -BeFalse
    }

    It 'honors the requested scope' {
        Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\EasypeasyUser\bin' }

        Test-SystemPathLocation -Location 'C:\EasypeasyUser\bin' -User | Should -BeTrue
        Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User }
    }

    It 'rejects both -Machine and -User' {
        { Test-SystemPathLocation -Location 'C:\x' -Machine -User } |
            Should -Throw '*Parameter set cannot be resolved*'
    }
}
