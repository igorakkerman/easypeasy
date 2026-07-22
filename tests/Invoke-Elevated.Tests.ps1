BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force

    # Pester's Mock needs 'sudo' discoverable; the Windows sudo feature is absent on
    # Server-based CI runners. Provide a stub on Path so mocks resolve — it never runs.
    if (-not (Get-Command sudo -ErrorAction SilentlyContinue)) {
        $script:sudoStub = Join-Path ([IO.Path]::GetTempPath()) "sudostub-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:sudoStub | Out-Null
        Set-Content -Path (Join-Path $script:sudoStub 'sudo.cmd') -Value '@echo off'
        $env:PATH = "$script:sudoStub$([IO.Path]::PathSeparator)$env:PATH"
    }
}

AfterAll {
    if ($script:sudoStub) {
        $env:PATH = ($env:PATH -split [IO.Path]::PathSeparator |
            Where-Object { $_ -ne $script:sudoStub }) -join [IO.Path]::PathSeparator
        Remove-Item $script:sudoStub -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-Elevated' {

    It 'runs the command inline as administrator via sudo' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated addpath -machine 'C:\Tools'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            $args -contains '--inline' -and
            $args -contains '-NoProfile' -and
            $args -contains '-EncodedCommand' -and
            ([System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq 'addpath -machine C:\Tools; exit $LASTEXITCODE')
        }
    }

    It 'single-quotes arguments that contain whitespace' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated New-Item 'C:\Program Files\X'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq "New-Item 'C:\Program Files\X'; exit `$LASTEXITCODE"
        }
    }

    It 'is exposed through the <alias> alias' -ForEach @(
        @{ alias = 'sudops' }
        @{ alias = 'sups' }
    ) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        & $alias rmenv -Machine JAVA_HOME

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq 'rmenv -Machine JAVA_HOME; exit $LASTEXITCODE'
        }
    }

    It 'reports a terminating error when the elevated command exits non-zero' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 1 }

        { Invoke-Elevated addpath -Machine 'C:\Tools' } | Should -Throw '*exitCode: 1*'
    }

    It 'treats a non-terminating error in the elevated command as success' {
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

    It 'reports a terminating error when sudo is not available' {
        Mock -ModuleName easypeasy Get-Command { } -ParameterFilter { $Name -eq 'sudo' }
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        { Invoke-Elevated addpath -Machine 'C:\Tools' } | Should -Throw '*sudo*'
        Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
    }

    It 'does not elevate under -WhatIf' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated -WhatIf addpath

        Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
    }
}
