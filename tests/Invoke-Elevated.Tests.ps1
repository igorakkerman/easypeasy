BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Invoke-Elevated' {

    # mocking sudo requires the command to exist; CI runners may not ship it
    $script:hasSudo = [bool] (Get-Command sudo -ErrorAction SilentlyContinue)

    It 'runs the command inline as administrator via sudo' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated addpath -machine 'C:\Tools'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            $args -contains '--inline' -and
            $args -contains '-NoProfile' -and
            $args -contains '-EncodedCommand' -and
            ([System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq 'addpath -machine C:\Tools; exit $LASTEXITCODE')
        }
    }

    It 'single-quotes arguments that contain whitespace' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated New-Item 'C:\Program Files\X'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq "New-Item 'C:\Program Files\X'; exit `$LASTEXITCODE"
        }
    }

    It 'is exposed through the <alias> alias' -Skip:(-not $hasSudo) -ForEach @(
        @{ alias = 'sudops' }
        @{ alias = 'sups' }
    ) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        & $alias rmenv -Machine JAVA_HOME

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq 'rmenv -Machine JAVA_HOME; exit $LASTEXITCODE'
        }
    }

    It 'reports a terminating error when the elevated command exits non-zero' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 1 }

        { Invoke-Elevated addpath -Machine 'C:\Tools' } | Should -Throw '*exitCode: 1*'
    }

    It 'treats a non-terminating error in the elevated command as success' -Skip:(-not $hasSudo) {
        # run the payload in a normal child process to exercise the real exit-code logic
        Mock -ModuleName easypeasy sudo {
            $stderr = New-TemporaryFile
            try {
                $child = Microsoft.PowerShell.Management\Start-Process -FilePath $args[1] `
                    -ArgumentList $args[2..($args.Count - 1)] -Wait -PassThru -NoNewWindow `
                    -RedirectStandardError $stderr.FullName
                $global:LASTEXITCODE = $child.ExitCode
            }
            finally {
                Remove-Item $stderr.FullName -ErrorAction SilentlyContinue
            }
        }

        { Invoke-Elevated Write-Error non-terminating } | Should -Not -Throw
    }

    It 'does not elevate under -WhatIf' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated -WhatIf addpath

        Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
    }
}
