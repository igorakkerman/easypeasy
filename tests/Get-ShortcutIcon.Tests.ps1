BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-ShortcutIcon' {

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
        InModuleScope easypeasy -Parameters @{ Lnk = $lnk } {
            Get-ShortcutIcon -Shortcut $Lnk | Should -Be 'C:\Windows\notepad.exe,0'
        }
    }
}
