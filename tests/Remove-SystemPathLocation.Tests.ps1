BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Remove-SystemPathLocation' {

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
