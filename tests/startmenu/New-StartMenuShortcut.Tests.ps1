BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    . "$PSScriptRoot/../ElevatedSession.ps1"
    Initialize-ElevatedSession
}

AfterAll { Remove-ElevatedSession }

Describe 'New-StartMenuShortcut' {

    BeforeAll {
        $script:folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-sm-$(New-Guid)"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    BeforeEach {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { "$folder\$Name" }
        Mock -ModuleName easypeasy Get-StartMenuProgramsLocation { $folder }
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy sudo { throw 'should not elevate' }
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

    It 'accepts -Administrator as alias of -Elevated' {
        $shortcut = New-StartMenuShortcut -Name 'AdminAlias' -Target 'C:\Windows\notepad.exe' -Administrator

        $shortcut.Elevated | Should -BeTrue
    }

    It 'takes the shortcut name positionally' {
        $shortcut = New-StartMenuShortcut 'Positional' -Target 'C:\Windows\notepad.exe'

        $shortcut.Location | Should -Be "$folder\Positional.lnk"
    }

    It 'takes the shortcut name and target positionally' {
        $shortcut = New-StartMenuShortcut 'PositionalBoth' 'C:\Windows\notepad.exe'

        $shortcut.Location | Should -Be "$folder\PositionalBoth.lnk"
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

    Context 'when not elevated' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy sudo -MockWith $sudoMock
            Mock -ModuleName easypeasy Get-SudoModeValue { 3 }
        }

        It 'creates the shortcut in the Programs root elevated for -AllUsers' {
            $shortcut = New-StartMenuShortcut -Name 'ElevatedRoot' -Target 'C:\Windows\notepad.exe' -AllUsers

            "$folder\ElevatedRoot.lnk" | Should -Exist
            $shortcut.Location | Should -Be "$folder\ElevatedRoot.lnk"
            $shortcut.Target   | Should -Be 'C:\Windows\notepad.exe'
            Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly
        }

        It 'creates the shortcut in the given -Folder elevated for -AllUsers' {
            New-StartMenuShortcut -Name 'AllUsersFolder' -Target 'C:\Windows\notepad.exe' -Folder 'AllUsersDir' -AllUsers | Out-Null

            "$folder\AllUsersDir\AllUsersFolder.lnk" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly
        }

        It 'carries every field into the shortcut it creates for -AllUsers' {
            New-StartMenuShortcut -Name 'AllUsersFields' -Target 'C:\Windows\notepad.exe' -AllUsers `
                -Arguments '/A C:\temp\file.txt' `
                -RunLocation 'C:\temp' `
                -Description 'Edit file' `
                -Icon 'C:\Windows\explorer.exe,3' `
                -Hotkey 'Ctrl+Alt+N' `
                -WindowStyle Maximized `
                -Elevated | Out-Null

            $result = Get-Shortcut "$folder\AllUsersFields.lnk"
            $result.Arguments       | Should -Be '/A C:\temp\file.txt'
            $result.RunLocation     | Should -Be 'C:\temp'
            $result.Description     | Should -Be 'Edit file'
            $result.Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,3'
            $result.Hotkey          | Should -Be 'Alt+Ctrl+N'
            $result.WindowStyle     | Should -Be 'Maximized'
            $result.Elevated        | Should -BeTrue
        }

        It 'fails for -AllUsers when the shortcut already exists without -Force' {
            New-StartMenuShortcut -Name 'AllUsersDup' -Target 'C:\Windows\notepad.exe' -AllUsers | Out-Null

            { New-StartMenuShortcut -Name 'AllUsersDup' -Target 'C:\Windows\regedit.exe' -AllUsers } |
                Should -Throw '*already exists*'

            (Get-Shortcut "$folder\AllUsersDup.lnk").Target | Should -Be 'C:\Windows\notepad.exe'
        }

        It 'overwrites an existing shortcut for -AllUsers with -Force' {
            New-StartMenuShortcut -Name 'AllUsersOver' -Target 'C:\Windows\notepad.exe' -AllUsers | Out-Null

            New-StartMenuShortcut -Name 'AllUsersOver' -Target 'C:\Windows\regedit.exe' -AllUsers -Force | Out-Null

            (Get-Shortcut "$folder\AllUsersOver.lnk").Target | Should -Be 'C:\Windows\regedit.exe'
        }

        It 'does not elevate for the current user' {
            New-StartMenuShortcut -Name 'UserApp' -Target 'C:\Windows\notepad.exe' | Out-Null

            "$folder\UserApp.lnk" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'creates nothing and does not elevate under -WhatIf' {
            New-StartMenuShortcut -Name 'WhatIfAllUsers' -Target 'C:\Windows\notepad.exe' -AllUsers -WhatIf | Out-Null

            "$folder\WhatIfAllUsers.lnk" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'fails for -AllUsers before anything is created when sudo is not available' {
            Mock -ModuleName easypeasy Get-SudoModeValue { 0 }

            { New-StartMenuShortcut -Name 'NoSudo' -Target 'C:\Windows\notepad.exe' -AllUsers } | Should -Throw '*sudo*'

            "$folder\NoSudo.lnk" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }
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
            -Icon 'C:\Windows\explorer.exe,3' `
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

    It 'takes the icon as an icon file and an index' {
        $icon = (New-StartMenuShortcut -Name 'IconWithIndex' -Target 'C:\Windows\notepad.exe' `
                -Icon 'C:\Windows\explorer.exe,3').Icon

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 3
    }

    It 'takes the icon as an icon file on its own, at index 0' {
        $icon = (New-StartMenuShortcut -Name 'IconFileOnly' -Target 'C:\Windows\notepad.exe' `
                -Icon 'C:\Windows\explorer.exe').Icon

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 0
    }
}
