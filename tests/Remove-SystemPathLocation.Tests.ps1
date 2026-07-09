BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Remove-SystemPathLocation' {

    Context 'delegation' {

        BeforeEach {
            $script:originalPath = $env:PATH
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\Old;C:\Gone' }
            Mock -ModuleName easypeasy Remove-PathLocation { 'C:\Old' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the trimmed path via Set-SystemPath' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Path -eq 'C:\Old' -and $User }
        }

        It 'does not persist under -WhatIf' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'error handling honours -ErrorAction (issue #1)' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Remove-PathLocation runs; the location is not present.
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\Other' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'stays silent with -ErrorAction SilentlyContinue' {
            { Remove-SystemPathLocation -Location 'C:\Gone' -User -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }

        It 'throws with -ErrorAction Stop' {
            { Remove-SystemPathLocation -Location 'C:\Gone' -User -ErrorAction Stop } |
                Should -Throw '*not found*'
        }

        It 'does not persist when the location is absent' {
            Remove-SystemPathLocation -Location 'C:\Gone' -User -ErrorAction SilentlyContinue
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }
}
