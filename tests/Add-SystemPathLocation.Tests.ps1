BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Add-SystemPathLocation' {

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
