BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Invoke-Elevated' {

    It 'runs the command in an elevated pwsh via Start-Process -Verb RunAs' {
        Mock -ModuleName easypeasy Start-Process { [pscustomobject] @{ ExitCode = 0 } }

        Invoke-Elevated addpath -machine 'C:\Tools'

        Should -Invoke -ModuleName easypeasy Start-Process -Times 1 -Exactly -ParameterFilter {
            $Verb -eq 'RunAs' -and
            $ArgumentList -contains '-NoProfile' -and
            $ArgumentList -contains '-EncodedCommand' -and
            ([System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($ArgumentList[-1])) -eq 'addpath -machine C:\Tools; exit $LASTEXITCODE')
        }
    }

    It 'single-quotes arguments that contain whitespace' {
        Mock -ModuleName easypeasy Start-Process { [pscustomobject] @{ ExitCode = 0 } }

        Invoke-Elevated New-Item 'C:\Program Files\X'

        Should -Invoke -ModuleName easypeasy Start-Process -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($ArgumentList[-1])) -eq "New-Item 'C:\Program Files\X'; exit `$LASTEXITCODE"
        }
    }

    It 'is exposed through the <alias> alias' -ForEach @(
        @{ alias = 'sudops' }
        @{ alias = 'sups' }
    ) {
        Mock -ModuleName easypeasy Start-Process { [pscustomobject] @{ ExitCode = 0 } }

        & $alias rmenv -Machine JAVA_HOME

        Should -Invoke -ModuleName easypeasy Start-Process -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($ArgumentList[-1])) -eq 'rmenv -Machine JAVA_HOME; exit $LASTEXITCODE'
        }
    }

    It 'reports a terminating error when the elevated session exits non-zero' {
        Mock -ModuleName easypeasy Start-Process { [pscustomobject] @{ ExitCode = 1 } }

        { Invoke-Elevated addpath -Machine 'C:\Tools' } | Should -Throw '*exit code 1*'
    }

    It 'treats a non-terminating error in the elevated command as success' {
        # run the elevated payload in a normal child process to exercise the real exit-code logic
        Mock -ModuleName easypeasy Start-Process {
            $stderr = New-TemporaryFile
            try {
                Microsoft.PowerShell.Management\Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
                    -Wait -PassThru -NoNewWindow -RedirectStandardError $stderr.FullName
            }
            finally {
                Remove-Item $stderr.FullName -ErrorAction SilentlyContinue
            }
        }

        { Invoke-Elevated Write-Error non-terminating } | Should -Not -Throw
    }

    It 'does not elevate under -WhatIf' {
        Mock -ModuleName easypeasy Start-Process { [pscustomobject] @{ ExitCode = 0 } }

        Invoke-Elevated -WhatIf addpath

        Should -Invoke -ModuleName easypeasy Start-Process -Times 0 -Exactly
    }
}
