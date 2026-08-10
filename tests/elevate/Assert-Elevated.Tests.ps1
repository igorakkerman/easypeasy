BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
}

Describe 'Assert-Elevated' {

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
}
