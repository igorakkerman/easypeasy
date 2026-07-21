BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Set-ShortcutLocationRunAsAdministrator' {

    BeforeEach {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        [System.IO.File]::WriteAllBytes($lnk, (New-Object byte[] 30))
    }

    AfterEach { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'sets the run-as-administrator flag (byte 0x15, bit 0x20)' {
        Set-ShortcutLocationRunAsAdministrator -ShortcutLocation $lnk

        $bytes = [System.IO.File]::ReadAllBytes($lnk)
        ($bytes[0x15] -band 0x20) | Should -Be 0x20
    }

    It 'leaves the file untouched under -WhatIf' {
        Set-ShortcutLocationRunAsAdministrator -ShortcutLocation $lnk -WhatIf

        $bytes = [System.IO.File]::ReadAllBytes($lnk)
        ($bytes[0x15] -band 0x20) | Should -Be 0
    }
}
