$script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

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

    It 'reports the elevation of the current session' {
        Test-Elevated | Should -Be $isAdmin
    }
}
