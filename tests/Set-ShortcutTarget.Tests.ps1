BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Set-ShortcutTarget' {

    BeforeEach {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($lnk)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.Save()
    }

    AfterEach { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'sets the target path of a shortcut' {
        Set-ShortcutTarget -Shortcut $lnk -Target 'C:\Windows\regedit.exe'

        $wsh = New-Object -ComObject WScript.Shell
        $wsh.CreateShortcut($lnk).TargetPath | Should -Be 'C:\Windows\regedit.exe'
    }

    It 'leaves the shortcut untouched under -WhatIf' {
        Set-ShortcutTarget -Shortcut $lnk -Target 'C:\Windows\regedit.exe' -WhatIf

        $wsh = New-Object -ComObject WScript.Shell
        $wsh.CreateShortcut($lnk).TargetPath | Should -Be 'C:\Windows\notepad.exe'
    }
}
