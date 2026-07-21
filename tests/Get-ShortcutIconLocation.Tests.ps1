BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-ShortcutIconLocation' {

    BeforeAll {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($lnk)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.IconLocation = 'C:\Windows\notepad.exe,0'
        $shortcut.Save()
    }

    AfterAll { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'returns the icon location of a shortcut' {
        Get-ShortcutIconLocation -Location $lnk | Should -Be 'C:\Windows\notepad.exe,0'
    }
}
