BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Optimize-SystemPath' {

    It 'removes duplicate locations from both scopes' {
        Mock -ModuleName easypeasy Remove-DuplicateSystemPathLocations { }

        Optimize-SystemPath

        Should -Invoke -ModuleName easypeasy Remove-DuplicateSystemPathLocations -Times 1 -Exactly `
            -ParameterFilter { -not $Machine -and -not $User -and -not $KeepMachine -and -not $KeepUser }
    }

    Context 'gating' {

        BeforeEach {
            $script:originalPath = $env:PATH
            Mock -ModuleName easypeasy Set-SystemPath { }
            Mock -ModuleName easypeasy Test-Elevated { $true }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $Machine } `
                { New-PathEntries 'C:\A;C:\B;C:\A' -Scope Machine }
            Mock -ModuleName easypeasy Get-SystemPath -ParameterFilter { $User } `
                { New-PathEntries 'C:\C;C:\C' }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the cleaned Path' {
            Optimize-SystemPath

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 2 -Exactly
        }

        # -WhatIf reaches the cleanup steps through the preference variable it sets
        It 'does not persist under -WhatIf' {
            Optimize-SystemPath -WhatIf

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    It 'is aliased by cleanpath' {
        (Get-Alias cleanpath).Definition | Should -Be 'Optimize-SystemPath'
    }
}
