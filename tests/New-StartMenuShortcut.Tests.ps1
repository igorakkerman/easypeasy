BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'New-StartMenuShortcut' {

    BeforeAll {
        $script:folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-sm-$(New-Guid)"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    BeforeEach {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }
        Mock -ModuleName easypeasy Get-StartMenuProgramsLocation { $folder }
    }

    AfterAll { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }

    It 'creates a .lnk pointing at the target' {
        $shortcut = New-StartMenuShortcut -Name 'MyApp' -Target 'C:\Windows\notepad.exe'

        $shortcut.Location | Should -Exist
        (Get-Shortcut $shortcut.Location).Target | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'returns the created shortcut' {
        $shortcut = New-StartMenuShortcut -Name 'Returned' -Target 'C:\Windows\notepad.exe'

        $shortcut.GetType().Name | Should -Be 'Shortcut'
        $shortcut.Location | Should -Be "$folder\Returned.lnk"
        $shortcut.Target   | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'creates nothing and returns nothing under -WhatIf' {
        $shortcut = New-StartMenuShortcut -Name 'WhatIfApp' -Target 'C:\Windows\notepad.exe' -WhatIf

        $shortcut | Should -BeNullOrEmpty
        "$folder\WhatIfApp.lnk" | Should -Not -Exist
    }

    It 'creates the shortcut in the given -Folder' {
        New-StartMenuShortcut -Name 'InFolder' -Target 'C:\Windows\notepad.exe' -Folder 'MyFolder' | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'MyFolder' }
    }

    It 'creates a -Folder that does not exist yet' {
        $newFolder = Join-Path $folder "Fresh-$(New-Guid)"
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $newFolder }

        New-StartMenuShortcut -Name 'Fresh' -Target 'C:\Windows\notepad.exe' -Folder 'Fresh' | Out-Null

        "$newFolder\Fresh.lnk" | Should -Exist
    }

    It 'reports no missing folder under -WhatIf for a -Folder that does not exist yet' {
        $newFolder = Join-Path $folder "WhatIf-$(New-Guid)"
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $newFolder }

        New-StartMenuShortcut -Name 'WhatIfFresh' -Target 'C:\Windows\notepad.exe' -Folder 'WhatIfFresh' -WhatIf `
            -ErrorVariable shortcutError -ErrorAction SilentlyContinue

        $shortcutError | Should -BeNullOrEmpty
        $newFolder | Should -Not -Exist
    }

    It 'creates the shortcut in the Programs root when -Folder is omitted' {
        New-StartMenuShortcut -Name 'InRoot' -Target 'C:\Windows\notepad.exe' | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly
        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 0 -Exactly
    }

    It 'forwards -AllUsers to New-StartMenuProgramsFolder' {
        New-StartMenuShortcut -Name 'AllUsersApp' -Target 'C:\Windows\notepad.exe' -Folder 'MyFolder' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'forwards -AllUsers to Get-StartMenuProgramsLocation when -Folder is omitted' {
        New-StartMenuShortcut -Name 'AllUsersRoot' -Target 'C:\Windows\notepad.exe' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'does not target the All Users folder by default' {
        New-StartMenuShortcut -Name 'DefaultApp' -Target 'C:\Windows\notepad.exe' | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly `
            -ParameterFilter { -not $AllUsers }
    }

    It 'requires -Name' {
        { New-StartMenuShortcut -Target 'C:\Windows\notepad.exe' -ErrorAction Stop } | Should -Throw
    }

    It 'requires -Target' {
        { New-StartMenuShortcut -Name 'NoTarget' -ErrorAction Stop } | Should -Throw
    }

    It 'fails when the shortcut already exists without -Force' {
        New-StartMenuShortcut -Name 'Dup' -Target 'C:\Windows\notepad.exe' | Out-Null

        { New-StartMenuShortcut -Name 'Dup' -Target 'C:\Windows\notepad.exe' } |
            Should -Throw '*already exists*'
    }

    It 'overwrites an existing shortcut with -Force' {
        New-StartMenuShortcut -Name 'Over' -Target 'C:\Windows\notepad.exe' | Out-Null

        (New-StartMenuShortcut -Name 'Over' -Target 'C:\Windows\regedit.exe' -Force).Target |
            Should -Be 'C:\Windows\regedit.exe'
    }

    It 'defaults the run location to the folder of the target' {
        (New-StartMenuShortcut -Name 'RunLocationDefault' -Target 'C:\Windows\notepad.exe').RunLocation |
            Should -Be 'C:\Windows'
    }

    It 'defaults every optional field' {
        $shortcut = New-StartMenuShortcut -Name 'Defaults' -Target 'C:\Windows\notepad.exe'

        $shortcut.Arguments   | Should -BeNullOrEmpty
        $shortcut.Description | Should -BeNullOrEmpty
        $shortcut.Icon        | Should -BeNullOrEmpty
        $shortcut.Hotkey      | Should -BeNullOrEmpty
        $shortcut.WindowStyle | Should -Be 'Normal'
        $shortcut.Elevated    | Should -BeFalse
    }

    It 'sets every field passed' {
        $shortcut = New-StartMenuShortcut -Name 'EveryField' -Target 'C:\Windows\notepad.exe' `
            -Arguments '/A C:\temp\file.txt' `
            -RunLocation 'C:\temp' `
            -Description 'Edit file' `
            -Icon (New-ShortcutIcon -Location 'C:\Windows\explorer.exe' -Index 3) `
            -Hotkey 'Ctrl+Alt+N' `
            -WindowStyle Maximized `
            -Elevated

        $result = Get-Shortcut $shortcut.Location
        $result.Arguments       | Should -Be '/A C:\temp\file.txt'
        $result.RunLocation     | Should -Be 'C:\temp'
        $result.Description     | Should -Be 'Edit file'
        $result.Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,3'
        $result.Hotkey          | Should -Be 'Alt+Ctrl+N'
        $result.WindowStyle     | Should -Be 'Maximized'
        $result.Elevated        | Should -BeTrue
    }

    It 'takes the icon as a ShortcutIcon record' {
        $icon = (New-StartMenuShortcut -Name 'IconRecord' -Target 'C:\Windows\notepad.exe' `
                -Icon (New-ShortcutIcon 'C:\Windows\explorer.exe,3')).Icon

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 3
    }

    It 'rejects an icon that is not a ShortcutIcon record' {
        { New-StartMenuShortcut -Name 'IconString' -Target 'C:\Windows\notepad.exe' `
                -Icon 'C:\Windows\explorer.exe,3' } |
            Should -Throw '*ShortcutIcon*'
    }
}
