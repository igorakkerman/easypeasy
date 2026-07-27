$script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Test-Elevation' {

    It 'exports the command' {
        Get-Command Test-Elevation -Module easypeasy | Should -Not -BeNullOrEmpty
    }

    It 'returns a boolean' {
        Test-Elevation | Should -BeOfType [bool]
    }

    It 'reports the elevation of the current session' {
        Test-Elevation | Should -Be $isAdmin
    }
}
