BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
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
        (Get-Shortcut -Location $lnk).GetType().Name | Should -Be 'Shortcut'
    }

    It 'takes the shortcut location positionally' {
        (Get-Shortcut $lnk).Location | Should -Be $lnk
    }

    It 'returns every readable field of the shortcut' {
        $result = Get-Shortcut -Location $lnk

        $result.Location           | Should -Be $lnk
        $result.Target             | Should -Be 'C:\Windows\notepad.exe'
        $result.Arguments          | Should -Be '/A C:\temp\file.txt'
        $result.RunLocation        | Should -Be 'C:\temp'
        $result.Description        | Should -Be 'Edit file'
        $result.Icon.ToString()         | Should -Be 'C:\Windows\notepad.exe,0'
        $result.Icon.Location      | Should -Be 'C:\Windows\notepad.exe'
        $result.Icon.Index         | Should -Be 0
        $result.Hotkey             | Should -Be 'Alt+Ctrl+N'
        $result.WindowStyle        | Should -Be 'Maximized'
        $result.Elevated           | Should -BeFalse
    }

    It 'reports the run-as-administrator flag' {
        $elevated = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($elevated)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.Save()

        try {
            (Get-Shortcut -Location $elevated).Elevated | Should -BeFalse

            Set-Shortcut -Location $elevated -Elevated

            (Get-Shortcut -Location $elevated).Elevated | Should -BeTrue
        }
        finally {
            Remove-Item $elevated -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns a ShortcutIcon record for the icon' {
        (Get-Shortcut -Location $lnk).Icon.GetType().Name | Should -Be 'ShortcutIcon'
    }

    It 'splits icon file and index at the last comma' {
        $lnkWithComma = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkWithComma)
        $shortcut.TargetPath   = 'C:\Windows\notepad.exe'
        $shortcut.IconLocation = 'C:\Program Files\App, Inc\app.exe,3'
        $shortcut.Save()

        try {
            $result = Get-Shortcut -Location $lnkWithComma

            $result.Icon.ToString()    | Should -Be 'C:\Program Files\App, Inc\app.exe,3'
            $result.Icon.Location | Should -Be 'C:\Program Files\App, Inc\app.exe'
            $result.Icon.Index    | Should -Be 3
        }
        finally {
            Remove-Item $lnkWithComma -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports an error for a missing shortcut' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"

        Get-Shortcut -Location $missing -ErrorVariable shortcutError -ErrorAction SilentlyContinue

        $shortcutError.CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $shortcutError.FullyQualifiedErrorId | Should -BeLike 'ShortcutNotFound,*'
        $shortcutError.TargetObject | Should -Be $missing

        # reading a shortcut must not create one
        $missing | Should -Not -Exist
    }

    It 'returns nothing for a missing shortcut' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"

        $result = Get-Shortcut -Location $missing -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
    }

    It 'returns no icon for a shortcut carrying none' {
        $lnkWithoutIcon = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkWithoutIcon)
        $shortcut.TargetPath = 'C:\Windows\notepad.exe'
        $shortcut.Save()

        try {
            (Get-Shortcut -Location $lnkWithoutIcon).Icon | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item $lnkWithoutIcon -Force -ErrorAction SilentlyContinue
        }
    }
}
