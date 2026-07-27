$script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Assert-Elevated' {

    # the two mocked cases cover both branches on every run, whichever way the runner was started
    It 'throws when the session is not elevated' {
        Mock -ModuleName easypeasy Test-Elevated { $false }

        $errorRecord = { Assert-Elevated } | Should -Throw '*administrator privileges*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'PermissionDenied'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ElevationRequired,*'
        $errorRecord.TargetObject | Should -Be ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    }

    It 'is silent when the session is elevated' {
        Mock -ModuleName easypeasy Test-Elevated { $true }

        { Assert-Elevated } | Should -Not -Throw
    }

    It 'throws for a non-administrator' -Skip:$isAdmin {
        { Assert-Elevated } | Should -Throw '*administrator privileges*'
    }

    It 'is silent for an administrator' -Skip:(-not $isAdmin) {
        { Assert-Elevated } | Should -Not -Throw
    }
}
