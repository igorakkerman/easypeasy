BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Invoke-Elevated' {

    # sudo.exe ships only on recent Windows clients, not on the CI runner.
    $script:hasSudo = [bool] (Get-Command sudo -ErrorAction SilentlyContinue)

    It 'runs the command in an elevated pwsh via sudo' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { }

        Invoke-Elevated addpath -machine 'C:\Tools'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'pwsh' -and
            $args -contains '-NoProfile' -and
            $args -contains '-Command' -and
            $args[-1] -eq 'addpath -machine C:\Tools'
        }
    }

    It 'single-quotes arguments that contain whitespace' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { }

        Invoke-Elevated New-Item 'C:\Program Files\X'

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            $args[-1] -eq "New-Item 'C:\Program Files\X'"
        }
    }

    It 'is exposed through the <alias> alias' -Skip:(-not $hasSudo) -ForEach @(
        @{ alias = 'sudops' }
        @{ alias = 'sups' }
    ) {
        Mock -ModuleName easypeasy sudo { }

        & $alias rmenv -Machine JAVA_HOME

        Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly -ParameterFilter {
            $args[-1] -eq 'rmenv -Machine JAVA_HOME'
        }
    }

    It 'does not invoke sudo under -WhatIf' -Skip:(-not $hasSudo) {
        Mock -ModuleName easypeasy sudo { }

        Invoke-Elevated -WhatIf addpath

        Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
    }
}
