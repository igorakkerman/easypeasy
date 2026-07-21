$script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Assert-Elevated' {

    It 'throws for a non-administrator' -Skip:$isAdmin {
        { Assert-Elevated } | Should -Throw '*administrator privileges*'
    }

    It 'is silent for an administrator' -Skip:(-not $isAdmin) {
        { Assert-Elevated } | Should -Not -Throw
    }
}
