BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
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

    It 'stays quiet about the variable that is not set' {
        $env:PATH = '%EASYPEASY_UNSET_XYZ%\bin;C:\EasypeasyRoot'

        Test-SystemPathLocation -Location '%EASYPEASY_UNSET_XYZ%\bin' -WarningVariable reported | Out-Null

        $reported | Should -BeNullOrEmpty
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

    Context 'from the pipeline' {

        It 'takes a piped entry as the location it stores' {
            Get-SystemPath -Exact 'C:\EasypeasyRoot' | Test-SystemPathLocation | Should -BeTrue
        }

        It 'takes the entry passed on inside ForEach-Object' {
            Get-SystemPath -Exact 'C:\EasypeasyRoot' | ForEach-Object { Test-SystemPathLocation $_ } |
                Should -BeTrue
        }

        It 'reports one result per piped location' {
            $results = @('C:\EasypeasyRoot', 'C:\Nope' | Test-SystemPathLocation)

            $results | Should -HaveCount 2
            $results[0] | Should -BeTrue
            $results[1] | Should -BeFalse
        }

        It 'reports one result per location given as an argument list' {
            $results = @(Test-SystemPathLocation -Location 'C:\EasypeasyRoot', 'C:\Nope')

            $results | Should -HaveCount 2
            $results[0] | Should -BeTrue
            $results[1] | Should -BeFalse
        }

        It 'reports nothing for an empty pipeline' {
            @(@() | Test-SystemPathLocation) | Should -HaveCount 0
        }
    }
}
