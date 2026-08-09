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
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\EasypeasyWin\System32' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '%windir%\system32\test' }
            # Windows expands the process block, so the persisted %...% reference does not appear in it
            $env:PATH = "C:\EasypeasyWin\System32;$env:windir\system32\test;C:\OnlyProcess"
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
            $result = Get-SystemPath | Where-Object { $_.Location -eq 'C:\EasypeasyWin\System32' }

            $result.Scope | Should -Be 'Machine'
            $result.StoredValue | Should -Be 'C:\EasypeasyWin\System32'
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

        It 'renders an entry as its stored value' {
            "$((Get-SystemPath -Machine -Contains 'S32'))" | Should -Be '%SystemRoot%\S32'
        }
    }

    Context 'a reference whose variable is not set' {

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } {
                '%EASYPEASY_UNSET_XYZ%\bin;C:\Plain'
            }
        }

        It 'lists the location, keeping the reference and leaving Location empty' {
            $result = Get-SystemPath -Machine -WarningAction SilentlyContinue

            $result.StoredValue | Should -Be @('%EASYPEASY_UNSET_XYZ%\bin', 'C:\Plain')
            $result[0].Location | Should -BeNullOrEmpty
        }

        It 'stays quiet, the listing marking the location itself' {
            Get-SystemPath -Machine -WarningVariable reported | Out-Null

            $reported | Should -BeNullOrEmpty
        }

        It 'selects the location on its stored form' {
            (Get-SystemPath -Machine -Contains 'EASYPEASY_UNSET_XYZ' -WarningAction SilentlyContinue).StoredValue |
                Should -Be '%EASYPEASY_UNSET_XYZ%\bin'
        }

        It 'selects the location by the reference spelled exactly' {
            (Get-SystemPath -Machine -Exact '%EASYPEASY_UNSET_XYZ%\bin\' -WarningAction SilentlyContinue).StoredValue |
                Should -Be '%EASYPEASY_UNSET_XYZ%\bin'
        }

        It 'leaves the resolvable locations alone' {
            Get-SystemPath -Machine -Contains 'Plain' -WarningVariable reported -WarningAction SilentlyContinue | Out-Null

            $reported | Should -BeNullOrEmpty
        }
    }

    Context 'normalized locations' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'normalizes <case> in Location, keeping the stored value verbatim' -ForEach @(
            @{ case = 'repeated backslashes'; stored = 'C:\EasypeasyTools\\bin'; location = 'C:\EasypeasyTools\bin' }
            @{ case = 'a trailing backslash'; stored = 'C:\EasypeasyTools\bin\'; location = 'C:\EasypeasyTools\bin' }
            @{ case = 'a .. segment'; stored = 'C:\EasypeasyTools\other\..\bin'; location = 'C:\EasypeasyTools\bin' }
            @{ case = 'a . segment'; stored = 'C:\EasypeasyTools\.\bin'; location = 'C:\EasypeasyTools\bin' }
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
            $env:PATH = 'C:\EasypeasyTools\\bin\'

            $result = Get-SystemPath

            $result.StoredValue | Should -BeExactly 'C:\EasypeasyTools\\bin\'
            $result.Location | Should -BeExactly 'C:\EasypeasyTools\bin'
        }

        It 'tags a location whose stored spelling differs from the process one' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\EasypeasyTools\\bin' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
            $env:PATH = 'C:\EasypeasyTools\bin\'

            $result = Get-SystemPath

            $result.Scope | Should -Be 'Machine'
            $result.StoredValue | Should -BeExactly 'C:\EasypeasyTools\\bin'
            $result.Location | Should -BeExactly 'C:\EasypeasyTools\bin'
        }
    }

    Context '-Exact' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns only the location equal to it' {
            $env:PATH = 'C:\EasypeasyWin;C:\Program Files\EasypeasyTool\bin'

            (Get-SystemPath -Exact 'C:\EasypeasyWin').Location | Should -Be @('C:\EasypeasyWin')
        }

        It 'matches the exact location, not a location containing it' {
            $env:PATH = 'C:\EasypeasyWin;C:\EasypeasyWin\System32'

            (Get-SystemPath -Exact 'C:\EasypeasyWin').Location | Should -Be @('C:\EasypeasyWin')
        }

        It 'matches case-insensitively and ignores trailing backslashes' {
            $env:PATH = 'C:\EasypeasyWin'

            (Get-SystemPath -Exact 'c:\easypeasywin\').Location | Should -Be @('C:\EasypeasyWin')
        }

        It 'ignores repeated backslashes on either side' {
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin'

            (Get-SystemPath -Exact 'C:\Program Files\\EasypeasyTool\bin').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin')

            $env:PATH = 'C:\Program Files\\EasypeasyTool\bin'

            $result = Get-SystemPath -Exact 'C:\Program Files\EasypeasyTool\bin'

            $result.StoredValue | Should -Be @('C:\Program Files\\EasypeasyTool\bin')
            $result.Location | Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'keeps the leading backslashes of a UNC root' {
            $env:PATH = '\\server\share'

            (Get-SystemPath -Exact '\\server\\share\').Location | Should -Be @('\\server\share')
            Get-SystemPath -Exact '\server\share' | Should -BeNullOrEmpty

            $env:PATH = '\server\share'

            Get-SystemPath -Exact '\\server\share' | Should -BeNullOrEmpty
        }

        It 'returns nothing when the location is absent' {
            $env:PATH = 'C:\EasypeasyWin'

            Get-SystemPath -Exact 'C:\Nope' | Should -BeNullOrEmpty
        }

        It 'tags the match with its origin scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\EasypeasyWin' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Users\easypeasy\bin' }
            $env:PATH = 'C:\EasypeasyWin;C:\Users\easypeasy\bin;C:\Temp\session'

            (Get-SystemPath -Exact 'C:\EasypeasyWin').Scope | Should -Be 'Machine'
            (Get-SystemPath -Exact 'C:\Users\easypeasy\bin').Scope | Should -Be 'User'
            (Get-SystemPath -Exact 'C:\Temp\session').Scope | Should -Be 'Process'
        }

        It 'holds a UNC root apart from a single leading backslash when tagging the scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { '\\server\share' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
            $env:PATH = '\server\share'

            (Get-SystemPath -Exact '\server\share').Scope | Should -Be 'Process'
        }

        It 'tags a location stored with repeated backslashes with its origin scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\EasypeasyTools\\bin' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { '' }
            $env:PATH = 'C:\EasypeasyTools\bin'

            $result = Get-SystemPath -Exact 'C:\EasypeasyTools\bin'

            $result.Scope | Should -Be 'Machine'
            $result.StoredValue | Should -Be 'C:\EasypeasyTools\\bin'
        }

        It 'searches the machine Path when -Machine is given' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\EasypeasyWin;C:\EasypeasyTools' }

            (Get-SystemPath -Exact 'C:\EasypeasyTools' -Machine).Scope | Should -Be 'Machine'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine }
        }

        It 'searches the user Path when -User is given' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\easypeasy\bin' }

            (Get-SystemPath -Exact 'C:\Users\easypeasy\bin' -User).Scope | Should -Be 'User'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }

        It 'rejects both -Machine and -User' {
            { Get-SystemPath -Exact 'C:\x' -Machine -User } |
                Should -Throw '*Parameter set cannot be resolved*'
        }

        It 'combines with the other criteria' {
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin;C:\Program Files\EasypeasyTool\cmd'

            (Get-SystemPath -Exact 'C:\Program Files\EasypeasyTool\bin' -Filter '*\bin').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin')

            Get-SystemPath -Exact 'C:\Program Files\EasypeasyTool\bin' -Filter '*\cmd' | Should -BeNullOrEmpty
        }

        It 'returns the stored form when -Join is used' {
            $env:PATH = 'C:\A;C:\B'

            Get-SystemPath -Exact 'C:\B' -Join | Should -Be 'C:\B'
        }

        It 'takes the location by its -Location and -Folder aliases' {
            $env:PATH = 'C:\EasypeasyWin;C:\EasypeasyTools'

            (Get-SystemPath -Location 'C:\EasypeasyTools').Location | Should -Be @('C:\EasypeasyTools')
            (Get-SystemPath -Folder 'C:\EasypeasyTools').Location | Should -Be @('C:\EasypeasyTools')
        }
    }

    Context '-Filter' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        It 'returns only locations matching the wildcard' {
            $env:PATH = 'C:\EasypeasyWin;C:\Program Files\EasypeasyTool\bin;C:\Users\easypeasy\bin'

            (Get-SystemPath -Filter '*\EasypeasyTool\*').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\EasypeasyWin;C:\Program Files\EasypeasyTool\bin'

            (Get-SystemPath -Filter '*easypeasytool*').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'ignores trailing backslashes on both sides' {
            $env:PATH = 'C:\EasypeasyTools\'

            (Get-SystemPath -Filter 'C:\EasypeasyTools').StoredValue | Should -Be @('C:\EasypeasyTools\')
        }

        It 'ignores repeated backslashes on both sides' {
            $env:PATH = 'C:\Program Files\\EasypeasyTool\bin'

            (Get-SystemPath -Filter '*\EasypeasyTool\bin').StoredValue |
                Should -Be @('C:\Program Files\\EasypeasyTool\bin')
            (Get-SystemPath -Filter '*\\EasypeasyTool\bin').StoredValue |
                Should -Be @('C:\Program Files\\EasypeasyTool\bin')
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
            $env:PATH = 'C:\EasypeasyWin;C:\Program Files\EasypeasyTool\bin;C:\Here\EasypeasyTool'

            (Get-SystemPath EasypeasyTool).Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin', 'C:\Here\EasypeasyTool')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\EasypeasyWin;C:\Program Files\EasypeasyTool\bin'

            (Get-SystemPath easypeasytool).Location | Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'takes the substring literally, so wildcards match nothing' {
            $env:PATH = 'C:\EasypeasyWin;C:\Program Files\EasypeasyTool\bin'

            Get-SystemPath '*EasypeasyTool*' | Should -BeNullOrEmpty
        }

        It 'requires all substrings to be contained' {
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin;C:\Program Files\EasypeasyTool\cmd'

            (Get-SystemPath EasypeasyTool bin).Location | Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'ignores repeated backslashes on both sides' {
            $env:PATH = 'C:\Program Files\\EasypeasyTool\bin'

            (Get-SystemPath '\EasypeasyTool\bin').StoredValue | Should -Be @('C:\Program Files\\EasypeasyTool\bin')
            (Get-SystemPath 'Files\\EasypeasyTool').StoredValue | Should -Be @('C:\Program Files\\EasypeasyTool\bin')
        }

        It 'reads a leading \\ as a UNC root, not as a repeated separator' {
            $env:PATH = 'C:\Program Files\\EasypeasyTool\bin;\\server\share'

            Get-SystemPath '\\EasypeasyTool\bin' | Should -BeNullOrEmpty
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
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin;C:\Program Files\EasypeasyTool\cmd;C:\EasypeasyWin'

            (Get-SystemPath -Match '\\EasypeasyTool\\(bin|cmd)$').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin', 'C:\Program Files\EasypeasyTool\cmd')
        }

        It 'matches case-insensitively' {
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin;C:\EasypeasyWin'

            (Get-SystemPath -Match 'easypeasytool').Location | Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'requires all regexes to match' {
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin;C:\Program Files\EasypeasyTool\cmd'

            (Get-SystemPath -Match '\\EasypeasyTool\\', 'bin$').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin')
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
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin;C:\Program Files\EasypeasyTool\cmd;C:\EasypeasyTools\bin'

            (Get-SystemPath EasypeasyTool -Filter '*\bin' -Match 'Program').Location |
                Should -Be @('C:\Program Files\EasypeasyTool\bin')
        }

        It 'returns nothing when one criterion excludes the rest' {
            $env:PATH = 'C:\Program Files\EasypeasyTool\bin'

            Get-SystemPath EasypeasyTool -Filter '*\cmd' | Should -BeNullOrEmpty
        }
    }

    Context 'scope tagging (effective)' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\WinDir;C:\Shared' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Users\easypeasy\bin;C:\Shared' }
        }

        It 'tags each location with its origin scope' {
            $env:PATH = 'C:\WinDir;C:\Users\easypeasy\bin;C:\Temp\session'

            $result = Get-SystemPath

            ($result | Where-Object Location -EQ 'C:\WinDir').Scope | Should -Be 'Machine'
            ($result | Where-Object Location -EQ 'C:\Users\easypeasy\bin').Scope | Should -Be 'User'
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

        It 'tags a location carrying an unresolved reference with its persisted scope' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } {
                'C:\Users\easypeasy\bin;%EASYPEASY_UNSET_XYZ%\bin'
            }
            $env:PATH = 'C:\Users\easypeasy\bin;%EASYPEASY_UNSET_XYZ%\bin'

            $result = Get-SystemPath -WarningAction SilentlyContinue

            ($result | Where-Object StoredValue -EQ '%EASYPEASY_UNSET_XYZ%\bin').Scope | Should -Be 'User'
        }

        It 'leaves an unresolved reference on no persisted Path tagged Process' {
            $env:PATH = '%EASYPEASY_UNSET_XYZ%\bin'

            (Get-SystemPath -WarningAction SilentlyContinue).Scope | Should -Be 'Process'
        }
    }

    Context '-Process' {

        BeforeAll { $script:originalPath = $env:PATH }
        AfterAll { $env:PATH = $script:originalPath }

        BeforeEach {
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $Machine } { 'C:\WinDir' }
            Mock -ModuleName easypeasy Get-EnvironmentVariable -ParameterFilter { $User } { 'C:\Users\easypeasy\bin' }
        }

        It 'returns only the locations on neither persisted Path' {
            $env:PATH = 'C:\WinDir;C:\Users\easypeasy\bin;C:\Temp\session;C:\Temp\other'

            $result = Get-SystemPath -Process

            $result.Location | Should -Be @('C:\Temp\session', 'C:\Temp\other')
            $result.Scope | Should -Be @('Process', 'Process')
        }

        It 'returns nothing when every location is persisted' {
            $env:PATH = 'C:\WinDir;C:\Users\easypeasy\bin'

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
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\EasypeasyWin;C:\EasypeasyWin\System32' }

            (Get-SystemPath -Machine).Location |
                Should -Be @('C:\EasypeasyWin', 'C:\EasypeasyWin\System32')

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine -and $Name -eq 'Path' }
        }

        It 'reads the user Path and honors -Join' {
            Mock -ModuleName easypeasy Get-EnvironmentVariable { 'C:\Users\easypeasy\bin' }

            Get-SystemPath -User -Join | Should -Be 'C:\Users\easypeasy\bin'

            Should -Invoke -ModuleName easypeasy Get-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User }
        }
    }
}
