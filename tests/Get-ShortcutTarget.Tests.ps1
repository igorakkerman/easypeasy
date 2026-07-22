BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-ShortcutTarget' {

    BeforeAll {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($lnk)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.Save()
    }

    AfterAll { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'returns the target path of a shortcut' {
        Get-ShortcutTarget -Shortcut $lnk | Should -Be 'C:\Windows\notepad.exe'
    }
}
