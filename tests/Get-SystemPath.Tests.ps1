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

        It 'reports the same stored and expanded location, the process Path being expanded' {
            $env:PATH = 'C:\A'

            $result = Get-SystemPath

            $result.StoredValue | Should -Be 'C:\A'
            $result.Location | Should -Be 'C:\A'
        }
    }

    Context 'expandable locations on the effective Path' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Windows\System32' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '%windir%\system32\test' }
            # Windows expands the process block, so the persisted %...% reference does not appear in it
            $env:PATH = "C:\Windows\System32;$env:windir\system32\test;C:\OnlyProcess"
        }

        It 'recovers the stored %...% form from the originating scope' {
            $result = Get-SystemPath -Contains 'system32\test'

            $result.Scope | Should -Be 'User'
            $result.StoredValue | Should -Be '%windir%\system32\test'
            $result.Location | Should -Be "$env:windir\system32\test"
        }

        It 'keeps a process-only location as its own stored form' {
            $result = Get-SystemPath | Where-Object { $_.Location -eq 'C:\OnlyProcess' }

            $result.Scope | Should -Be 'Process'
            $result.StoredValue | Should -Be 'C:\OnlyProcess'
        }

        It 'leaves a location persisted without a reference unchanged' {
            $result = Get-SystemPath | Where-Object { $_.Location -eq 'C:\Windows\System32' }

            $result.Scope | Should -Be 'Machine'
            $result.StoredValue | Should -Be 'C:\Windows\System32'
        }
    }

    Context 'expandable locations in a persisted scope' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } {
                '%SystemRoot%\S32;C:\Plain'
            }
        }

        It 'keeps the stored %...% reference in StoredValue' {
            (Get-SystemPath -Machine).StoredValue |
                Should -Be @('%SystemRoot%\S32', 'C:\Plain')
        }

        It 'expands the reference in Location' {
            (Get-SystemPath -Machine).Location |
                Should -Be @("$env:SystemRoot\S32", 'C:\Plain')
        }

        It 'reads the stored form, passing -Expandable' {
            Get-SystemPath -Machine | Out-Null

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Expandable }
        }

        It 'joins the stored form when -Join is used' {
            Get-SystemPath -Machine -Join | Should -Be '%SystemRoot%\S32;C:\Plain'
        }

        It 'selects on the expanded location' {
            (Get-SystemPath -Machine -Contains 'S32').StoredValue |
                Should -Be '%SystemRoot%\S32'
        }
    }

    Context 'normalized locations' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'normalizes <case> in Location, keeping the stored value verbatim' -ForEach @(
            @{ case = 'repeated backslashes'; stored = 'C:\Tools\\bin'; location = 'C:\Tools\bin' }
            @{ case = 'a trailing backslash'; stored = 'C:\Tools\bin\'; location = 'C:\Tools\bin' }
            @{ case = 'a .. segment'; stored = 'C:\Tools\other\..\bin'; location = 'C:\Tools\bin' }
            @{ case = 'a . segment'; stored = 'C:\Tools\.\bin'; location = 'C:\Tools\bin' }
        ) {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { $stored }

            $result = Get-SystemPath -Machine

            $result.StoredValue | Should -BeExactly $stored
            $result.Location | Should -BeExactly $location
        }

        It 'keeps the trailing backslash of a drive root, which names a folder' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\' }

            (Get-SystemPath -Machine).Location | Should -BeExactly 'C:\'
        }

        It 'keeps the leading backslashes of a UNC root' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { '\\server\\share\bin\' }

            (Get-SystemPath -Machine).Location | Should -BeExactly '\\server\share\bin'
        }

        It 'resolves a relative location against the current directory' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'bin' }

            (Get-SystemPath -Machine).Location | Should -BeExactly (Join-Path $PWD 'bin')
        }

        It 'returns null when a location cannot be normalized' {
            $stored = 'C:\' + ('a' * 40000)
            $result = InModuleScope easypeasy -Parameters @{ stored = $stored } {
                ConvertTo-NormalizedLocation -Location $stored
            }

            $result | Should -BeNullOrEmpty
        }

        It 'keeps an unresolvable stored value with a null Location' {
            $stored = 'C:\' + ('a' * 40000)
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { $stored }

            $result = Get-SystemPath -Machine

            $result.StoredValue | Should -BeExactly $stored
            $result.Location | Should -BeNullOrEmpty
        }

        It 'normalizes a location on the effective Path too' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { '' }
            $env:PATH = 'C:\Tools\\bin\'

            $result = Get-SystemPath

            $result.StoredValue | Should -BeExactly 'C:\Tools\\bin\'
            $result.Location | Should -BeExactly 'C:\Tools\bin'
        }

        It 'tags a location whose stored spelling differs from the process one' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Tools\\bin' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
            $env:PATH = 'C:\Tools\bin\'

            $result = Get-SystemPath

            $result.Scope | Should -Be 'Machine'
            $result.StoredValue | Should -BeExactly 'C:\Tools\\bin'
            $result.Location | Should -BeExactly 'C:\Tools\bin'
        }
    }

    Context '-Exact' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns only the location equal to it' {
            $env:PATH = 'C:\Windows;C:\Program Files\Git\bin'

            (Get-SystemPath -Exact 'C:\Windows').Location | Should -Be @('C:\Windows')
        }

        It 'matches the exact location, not a location containing it' {
            $env:PATH = 'C:\Windows;C:\Windows\System32'

            (Get-SystemPath -Exact 'C:\Windows').Location | Should -Be @('C:\Windows')
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            $env:PATH = 'C:\Windows'

            (Get-SystemPath -Exact 'c:\windows\').Location | Should -Be @('C:\Windows')
        }

        It 'ignores repeated backslashes on either side' {
            $env:PATH = 'C:\Program Files\Git\bin'

            (Get-SystemPath -Exact 'C:\Program Files\\Git\bin').Location |
                Should -Be @('C:\Program Files\Git\bin')

            $env:PATH = 'C:\Program Files\\Git\bin'

            $result = Get-SystemPath -Exact 'C:\Program Files\Git\bin'

            $result.StoredValue | Should -Be @('C:\Program Files\\Git\bin')
            $result.Location | Should -Be @('C:\Program Files\Git\bin')
        }

        It 'keeps the leading backslashes of a UNC root' {
            $env:PATH = '\\server\share'

            (Get-SystemPath -Exact '\\server\\share\').Location | Should -Be @('\\server\share')
            Get-SystemPath -Exact '\server\share' | Should -BeNullOrEmpty

            $env:PATH = '\server\share'

            Get-SystemPath -Exact '\\server\share' | Should -BeNullOrEmpty
        }

        It 'returns nothing when the location is absent' {
            $env:PATH = 'C:\Windows'

            Get-SystemPath -Exact 'C:\Nope' | Should -BeNullOrEmpty
        }

        It 'tags the match with its origin scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Windows' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Users\me\bin' }
            $env:PATH = 'C:\Windows;C:\Users\me\bin;C:\Temp\session'

            (Get-SystemPath -Exact 'C:\Windows').Scope | Should -Be 'Machine'
            (Get-SystemPath -Exact 'C:\Users\me\bin').Scope | Should -Be 'User'
            (Get-SystemPath -Exact 'C:\Temp\session').Scope | Should -Be 'Process'
        }

        It 'holds a UNC root apart from a single leading backslash when tagging the scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { '\\server\share' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
            $env:PATH = '\server\share'

            (Get-SystemPath -Exact '\server\share').Scope | Should -Be 'Process'
        }

        It 'tags a location stored with repeated backslashes with its origin scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\Tools\\bin' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
            $env:PATH = 'C:\Tools\bin'

            $result = Get-SystemPath -Exact 'C:\Tools\bin'

            $result.Scope | Should -Be 'Machine'
            $result.StoredValue | Should -Be 'C:\Tools\\bin'
        }

        It 'searches the machine Path when -Machine is given' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Windows;C:\Tools' }

            (Get-SystemPath -Exact 'C:\Tools' -Machine).Scope | Should -Be 'Machine'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine }
        }

        It 'searches the user Path when -User is given' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\me\bin' }

            (Get-SystemPath -Exact 'C:\Users\me\bin' -User).Scope | Should -Be 'User'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }

        It 'rejects both -Machine and -User' {
            { Get-SystemPath -Exact 'C:\x' -Machine -User } |
                Should -Throw '*Parameter set cannot be resolved*'
        }

        It 'combines with the other criteria' {
            $env:PATH = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd'

            (Get-SystemPath -Exact 'C:\Program Files\Git\bin' -Filter '*\bin').Location |
                Should -Be @('C:\Program Files\Git\bin')

            Get-SystemPath -Exact 'C:\Program Files\Git\bin' -Filter '*\cmd' | Should -BeNullOrEmpty
        }

        It 'returns the stored form when -Join is used' {
            $env:PATH = 'C:\A;C:\B'

            Get-SystemPath -Exact 'C:\B' -Join | Should -Be 'C:\B'
        }

        It 'takes the location by its -Location and -Folder aliases' {
            $env:PATH = 'C:\Windows;C:\Tools'

            (Get-SystemPath -Location 'C:\Tools').Location | Should -Be @('C:\Tools')
            (Get-SystemPath -Folder 'C:\Tools').Location | Should -Be @('C:\Tools')
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

            (Get-SystemPath -Filter 'C:\Tools').StoredValue | Should -Be @('C:\Tools\')
        }

        It 'ignores repeated backslashes on both sides' {
            $env:PATH = 'C:\Program Files\\Git\bin'

            (Get-SystemPath -Filter '*\Git\bin').StoredValue |
                Should -Be @('C:\Program Files\\Git\bin')
            (Get-SystemPath -Filter '*\\Git\bin').StoredValue |
                Should -Be @('C:\Program Files\\Git\bin')
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

        It 'ignores repeated backslashes on both sides' {
            $env:PATH = 'C:\Program Files\\Git\bin'

            (Get-SystemPath '\Git\bin').StoredValue | Should -Be @('C:\Program Files\\Git\bin')
            (Get-SystemPath 'Files\\Git').StoredValue | Should -Be @('C:\Program Files\\Git\bin')
        }

        It 'reads a leading \\ as a UNC root, not as a repeated separator' {
            $env:PATH = 'C:\Program Files\\Git\bin;\\server\share'

            Get-SystemPath '\\Git\bin' | Should -BeNullOrEmpty
            (Get-SystemPath '\\server').Location | Should -Be @('\\server\share')
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

    Context '-Process' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\WinDir' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Users\me\bin' }
        }

        It 'returns only the locations on neither persisted Path' {
            $env:PATH = 'C:\WinDir;C:\Users\me\bin;C:\Temp\session;C:\Temp\other'

            $result = Get-SystemPath -Process

            $result.Location | Should -Be @('C:\Temp\session', 'C:\Temp\other')
            $result.Scope | Should -Be @('Process', 'Process')
        }

        It 'returns nothing when every location is persisted' {
            $env:PATH = 'C:\WinDir;C:\Users\me\bin'

            Get-SystemPath -Process | Should -BeNullOrEmpty
        }

        It 'applies the criteria to the process-only locations' {
            $env:PATH = 'C:\WinDir;C:\Temp\session;C:\Temp\other'

            (Get-SystemPath -Process session).Location | Should -Be @('C:\Temp\session')
            Get-SystemPath -Process 'C:\WinDir' | Should -BeNullOrEmpty
        }

        It 'rejects both -Process and -Machine' {
            { Get-SystemPath -Process -Machine } |
                Should -Throw '*Parameter set cannot be resolved*'
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
