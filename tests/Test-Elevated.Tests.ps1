BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Test-Elevated' {

    It 'exports the command' {
        Get-Command Test-Elevated -Module easypeasy | Should -Not -BeNullOrEmpty
    }

    It 'returns a boolean' {
        Test-Elevated | Should -BeOfType [bool]
    }
}
