BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    # the stand-in defines sudo, so Pester resolves the name on a host without the Windows sudo feature
    . "$PSScriptRoot/../ElevatedSession.ps1"
    Initialize-ElevatedSession
}

AfterAll { Remove-ElevatedSession }

Describe 'Invoke-Elevated' {

    BeforeEach {
        # sudo feature enabled inline, whatever the host carries
        InModuleScope easypeasy { Mock Get-SudoModeValue { [SudoMode]::Inline } }
    }

    It 'runs the command inline as administrator via sudo' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated addpath -machine 'C:\Tools'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            $args -contains '--inline' -and
            $args -contains '-NoProfile' -and
            $args -contains '-EncodedCommand' -and
            ([System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -eq 'try { addpath -machine ''C:\Tools'' } catch { Write-Error -ErrorRecord $_; exit 1 }; exit ($LASTEXITCODE ?? 0)')
        }
    }

    It 'single-quotes arguments that contain whitespace' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated New-Item 'C:\Program Files\X'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { New-Item 'C:\Program Files\X' } catch *"
        }
    }

    It 'single-quotes an argument containing a semicolon, so it cannot reach the child as syntax' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated setenv -Name Path -Value 'C:\A;C:\B'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { setenv -Name 'Path' -Value 'C:\A;C:\B' } catch *"
        }
    }

    It 'doubles a single quote inside an argument' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated New-Item "C:\Sam's Tools"

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { New-Item 'C:\Sam''s Tools' } catch *"
        }
    }

    It 'single-quotes a value that merely starts with a dash, so it cannot reach the child as a parameter' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated New-Shortcut -Arguments '-Command "Get-Date"'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { New-Shortcut -Arguments '-Command `"Get-Date`"' } catch *"
        }
    }

    It 'passes a collection argument on as one array argument' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated rmpath -Location @('C:\A', 'C:\B') -Machine

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { rmpath -Location 'C:\A','C:\B' -Machine } catch *"
        }
    }

    It 'doubles a single quote inside an element of a collection argument' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated rmpath -Location @("C:\Sam's Tools", 'C:\B')

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { rmpath -Location 'C:\Sam''s Tools','C:\B' } catch *"
        }
    }

    It 'is exposed through the <alias> alias' -ForEach @(
        @{ alias = 'sudops' }
        @{ alias = 'sups' }
    ) {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        & $alias rmenv -Machine JAVA_HOME

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1])) -like "try { rmenv -Machine 'JAVA_HOME' } catch *"
        }
    }

    It 'reports a terminating error when the elevated command exits non-zero' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 1 }

        $errorRecord = { Invoke-Elevated addpath -Machine 'C:\Tools' } | Should -Throw '*exitCode: 1*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'OperationStopped'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ElevatedCommandFailed,*'
        $errorRecord.TargetObject | Should -Be "addpath -Machine 'C:\Tools'"
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

    It 'reports a terminating error when the elevated session cannot resolve the command' {
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

        $errorRecord = { Invoke-Elevated Invoke-NoSuchEasypeasyCommand } | Should -Throw '*exitCode: 1*' -PassThru

        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ElevatedCommandFailed,*'
    }

    It 'reports a terminating error when sudo is not available' {
        Mock -ModuleName easypeasy Get-Command { } -ParameterFilter { $Name -eq 'sudo' }
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        $errorRecord = { Invoke-Elevated addpath -Machine 'C:\Tools' } | Should -Throw '*sudo*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'NotInstalled'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoNotAvailable,*'
        $errorRecord.TargetObject | Should -Be 'sudo'
        Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
    }

    It 'does not elevate under -WhatIf' {
        Mock -ModuleName easypeasy sudo { $global:LASTEXITCODE = 0 }

        Invoke-Elevated -WhatIf addpath

        Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
    }
}
