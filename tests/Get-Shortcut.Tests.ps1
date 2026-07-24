BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-Shortcut' {

    BeforeAll {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($lnk)
        $shortcut.TargetPath       = 'C:\Windows\notepad.exe'
        $shortcut.Arguments        = '/A C:\temp\file.txt'
        $shortcut.WorkingDirectory = 'C:\temp'
        $shortcut.Description       = 'Edit file'
        $shortcut.IconLocation      = 'C:\Windows\notepad.exe,0'
        $shortcut.Hotkey            = 'Ctrl+Alt+N'
        $shortcut.WindowStyle       = 3
        $shortcut.Save()
    }

    AfterAll { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'returns a Shortcut record' {
        (Get-Shortcut -Shortcut $lnk).GetType().Name | Should -Be 'Shortcut'
    }

    It 'returns every readable field of the shortcut' {
        $result = Get-Shortcut -Shortcut $lnk

        $result.Shortcut           | Should -Be $lnk
        $result.Target             | Should -Be 'C:\Windows\notepad.exe'
        $result.Arguments          | Should -Be '/A C:\temp\file.txt'
        $result.StartIn            | Should -Be 'C:\temp'
        $result.Description        | Should -Be 'Edit file'
        $result.Icon.Value         | Should -Be 'C:\Windows\notepad.exe,0'
        $result.Icon.Location      | Should -Be 'C:\Windows\notepad.exe'
        $result.Icon.Index         | Should -Be 0
        $result.Hotkey             | Should -Be 'Alt+Ctrl+N'
        $result.WindowStyle        | Should -Be 'Maximized'
        $result.RunAsAdministrator | Should -BeFalse
    }

    It 'reports the run-as-administrator flag' {
        $elevated = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($elevated)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.Save()

        try {
            (Get-Shortcut -Shortcut $elevated).RunAsAdministrator | Should -BeFalse

            InModuleScope easypeasy -Parameters @{ Lnk = $elevated } {
                Set-ShortcutRunAsAdministrator -Shortcut $Lnk
            }

            (Get-Shortcut -Shortcut $elevated).RunAsAdministrator | Should -BeTrue
        }
        finally {
            Remove-Item $elevated -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns a ShortcutIcon record for the icon' {
        (Get-Shortcut -Shortcut $lnk).Icon.GetType().Name | Should -Be 'ShortcutIcon'
    }

    It 'splits icon file and index at the last comma' {
        $lnkWithComma = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkWithComma)
        $shortcut.TargetPath   = 'C:\Windows\notepad.exe'
        $shortcut.IconLocation = 'C:\Program Files\App, Inc\app.exe,3'
        $shortcut.Save()

        try {
            $result = Get-Shortcut -Shortcut $lnkWithComma

            $result.Icon.Value    | Should -Be 'C:\Program Files\App, Inc\app.exe,3'
            $result.Icon.Location | Should -Be 'C:\Program Files\App, Inc\app.exe'
            $result.Icon.Index    | Should -Be 3
        }
        finally {
            Remove-Item $lnkWithComma -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns no icon for a shortcut carrying none' {
        $lnkWithoutIcon = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkWithoutIcon)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.Save()

        try {
            (Get-Shortcut -Shortcut $lnkWithoutIcon).Icon | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item $lnkWithoutIcon -Force -ErrorAction SilentlyContinue
        }
    }
}
