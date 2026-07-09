BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Add-SystemPathLocation' {

    Context 'delegation' {

        BeforeEach {
            $script:originalPath = $env:PATH
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\Old' }
            Mock -ModuleName easypeasy Add-PathLocation { 'C:\Old;C:\New' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'persists the extended path via Set-SystemPath' {
            Add-SystemPathLocation -Location 'C:\New' -User

            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 1 -Exactly `
                -ParameterFilter { $Path -eq 'C:\Old;C:\New' -and $User }
        }

        It 'does not persist under -WhatIf' {
            Add-SystemPathLocation -Location 'C:\New' -User -WhatIf
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }

    Context 'error handling honours -ErrorAction (issue #1)' {

        BeforeEach {
            $script:originalPath = $env:PATH
            # Real Add-PathLocation runs; the location is already present.
            Mock -ModuleName easypeasy Get-SystemPath { 'C:\Exists' }
            Mock -ModuleName easypeasy Set-SystemPath { }
        }

        AfterEach { $env:PATH = $originalPath }

        It 'stays silent with -ErrorAction SilentlyContinue' {
            { Add-SystemPathLocation -Location 'C:\Exists' -User -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }

        It 'throws with -ErrorAction Stop' {
            { Add-SystemPathLocation -Location 'C:\Exists' -User -ErrorAction Stop } |
                Should -Throw '*already contains*'
        }

        It 'does not persist when the location is already present' {
            Add-SystemPathLocation -Location 'C:\Exists' -User -ErrorAction SilentlyContinue
            Should -Invoke -ModuleName easypeasy Set-SystemPath -Times 0 -Exactly
        }
    }
}
