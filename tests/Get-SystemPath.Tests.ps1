BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-SystemPath' {

    Context 'effective Path (default)' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns one SystemPathLocation per entry' {
            $env:PATH = 'C:\A;C:\B'

            $result = Get-SystemPath

            $result.Location | Should -Be @('C:\A', 'C:\B')
            $result[0].GetType().Name | Should -Be 'SystemPathLocation'
        }

        It 'skips empty entries such as a trailing semicolon' {
            $env:PATH = 'C:\A;;C:\B;'

            (Get-SystemPath).Location | Should -Be @('C:\A', 'C:\B')
        }

        It 'returns the raw string when -Join is used' {
            $env:PATH = 'C:\A;C:\B'

            Get-SystemPath -Join | Should -Be 'C:\A;C:\B'
        }
    }

    Context '-Filter' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns only locations matching the wildcard' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin;C:\Users\me\bin'

            (Get-SystemPath -Filter '*\Git\*').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'

            (Get-SystemPath -Filter '*git*').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'ignores trailing backslashes on both sides' {
            $env:PATH = 'C:\Tools\'

            (Get-SystemPath -Filter 'C:\Tools').Location | Should -Be @('C:\Tools\')
        }

        It 'returns the matches joined when -Join is used' {
            $env:PATH = 'C:\A;C:\B;C:\Bin'

            Get-SystemPath -Filter 'C:\B*' -Join | Should -Be 'C:\B;C:\Bin'
        }

        It 'returns nothing when no location matches' {
            $env:PATH = 'C:\A;C:\B'

            Get-SystemPath -Filter '*nomatch*' | Should -BeNullOrEmpty
        }
    }

    Context '-Contains' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns every location containing the substring, positionally and without wildcards' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin;C:\Here\Git'

            (Get-SystemPath Git).Location |
                Should -Be @('C:\Program Files\Git\bin', 'C:\Here\Git')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'

            (Get-SystemPath git).Location | Should -Be @('C:\Program Files\Git\bin')
        }

        It 'takes the substring literally, so wildcards match nothing' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'

            Get-SystemPath '*Git*' | Should -BeNullOrEmpty
        }

        It 'requires all substrings to be contained' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd'

            (Get-SystemPath Git bin).Location | Should -Be @('C:\Program Files\Git\bin')
        }

        It 'returns everything when no criterion is given' {
            $env:PATH = 'C:\A;C:\B'

            (Get-SystemPath).Location | Should -Be @('C:\A', 'C:\B')
        }
    }

    Context '-Match' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns only locations matching the regex' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd;C:\Windows'

            (Get-SystemPath -Match '\\Git\\(bin|cmd)$').Location |
                Should -Be @('C:\Program Files\Git\bin', 'C:\Program Files\Git\cmd')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Windows'

            (Get-SystemPath -Match 'git').Location | Should -Be @('C:\Program Files\Git\bin')
        }

        It 'requires all regexes to match' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd'

            (Get-SystemPath -Match '\\Git\\', 'bin$').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'rejects an invalid regex, reporting the pattern and the reason' {
            { Get-SystemPath -Match '(' } |
                Should -Throw -ExpectedMessage "*Invalid regular expression. pattern: '('*Not enough*"
        }

        It 'rejects an invalid regex among valid ones' {
            { Get-SystemPath -Match 'bin$', '(' } |
                Should -Throw -ExpectedMessage "*Invalid regular expression. pattern: '('*"
        }
    }

    Context 'combined criteria' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'requires criteria of different kinds to all be satisfied' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd;C:\Tools\bin'

            (Get-SystemPath Git -Filter '*\bin' -Match 'Program').Location |
                Should -Be @('C:\Program Files\Git\bin')
        }

        It 'returns nothing when one criterion excludes the rest' {
            $env:PATH = 'C:\Program Files\Git\bin'

            Get-SystemPath Git -Filter '*\cmd' | Should -BeNullOrEmpty
        }
    }

    Context 'scope tagging (effective)' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\WinDir;C:\Shared' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Users\me\bin;C:\Shared' }
        }

        It 'tags each location with its origin scope' {
            $env:PATH = 'C:\WinDir;C:\Users\me\bin;C:\Temp\session'

            $result = Get-SystemPath

            ($result | Where-Object Location -EQ 'C:\WinDir').Scope | Should -Be 'Machine'
            ($result | Where-Object Location -EQ 'C:\Users\me\bin').Scope | Should -Be 'User'
            ($result | Where-Object Location -EQ 'C:\Temp\session').Scope | Should -Be 'Process'
        }

        It 'tags a single occurrence of a location on both scopes as Machine' {
            $env:PATH = 'C:\Shared'

            (Get-SystemPath).Scope | Should -Be 'Machine'
        }

        It 'tags duplicate occurrences of a both-scopes location as Machine then User' {
            $env:PATH = 'C:\Shared;C:\Shared'

            (Get-SystemPath).Scope | Should -Be @('Machine', 'User')
        }
    }

    Context 'machine and user scopes read the Path environment variable' {

        It 'reads the machine Path via Get-EnvironmentVariable' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Windows;C:\Windows\System32' }

            (Get-SystemPath -Machine).Location |
                Should -Be @('C:\Windows', 'C:\Windows\System32')

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Name -eq 'Path' }
        }

        It 'reads the user Path and honors -Join' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

            Get-SystemPath -User -Join | Should -Be 'C:\Users\me\bin'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }
    }
}
