BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    . "$PSScriptRoot/../ElevatedSession.ps1"
    Initialize-ElevatedSession
}

AfterAll { Remove-ElevatedSession }

Describe 'New-PowershellStartMenuShortcut' {

    BeforeAll {
        $script:folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-ps-$(New-Guid)"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    BeforeEach {
        Mock -ModuleName easypeasy Get-StartMenuProgramsLocation { $folder }
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy sudo { throw 'should not elevate' }
    }

    AfterAll { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }

    It 'creates a pwsh shortcut that runs the command' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'ShowDate'

        $shortcut.Location  | Should -Exist
        $shortcut.Target    | Should -Match 'pwsh'
        $shortcut.Arguments | Should -Match '-Command'
    }

    It 'returns the created shortcut' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Returned'

        $shortcut.GetType().Name | Should -Be 'Shortcut'
        $shortcut.Location | Should -Be "$folder\Returned.lnk"
    }

    It 'keeps the window open with -KeepOpen (-NoExit)' {
        (New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'KeepOpen' -KeepOpen).Arguments |
            Should -Match '-NoExit'
    }

    It 'sets the run-as-administrator flag with -Elevated' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AsAdmin' -Elevated

        (Get-Shortcut $shortcut.Location).Elevated | Should -BeTrue
    }

    It 'accepts -Administrator as alias of -Elevated' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AdminAlias' -Administrator

        $shortcut.Elevated | Should -BeTrue
    }

    It 'takes the shortcut name positionally' {
        $shortcut = New-PowershellStartMenuShortcut 'Positional' -Command 'Get-Date'

        $shortcut.Location | Should -Be "$folder\Positional.lnk"
    }

    It 'takes the shortcut name and command positionally' {
        $shortcut = New-PowershellStartMenuShortcut 'PositionalBoth' 'Get-Date'

        $shortcut.Location  | Should -Be "$folder\PositionalBoth.lnk"
        $shortcut.Arguments | Should -Match 'Get-Date'
    }

    It 'leaves the target unelevated without -Elevated' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Unelevated'

        (Get-Shortcut $shortcut.Location).Elevated | Should -BeFalse
    }

    It 'creates nothing and returns nothing under -WhatIf, even with -Elevated' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'WhatIfAdmin' -Elevated -WhatIf

        $shortcut | Should -BeNullOrEmpty
        "$folder\WhatIfAdmin.lnk" | Should -Not -Exist
    }

    It 'minimizes the window by default' {
        (New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'WindowDefault').WindowStyle |
            Should -Be 'Minimized'
    }

    It 'launches the window in the given -WindowStyle' {
        (New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'WindowMaximized' -WindowStyle Maximized).WindowStyle |
            Should -Be 'Maximized'

        (New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'WindowNormal' -WindowStyle Normal).WindowStyle |
            Should -Be 'Normal'
    }

    It 'creates the shortcut in the given -Folder' {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }

        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'InFolder' -Folder 'MyFolder' | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'MyFolder' }
    }

    It 'forwards -AllUsers to Get-StartMenuProgramsLocation' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersRoot' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'forwards -AllUsers to New-StartMenuProgramsFolder' {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }

        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersFolder' -Folder 'MyFolder' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'does not target the All Users folder by default' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'DefaultScope' | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly `
            -ParameterFilter { -not $AllUsers }
    }

    Context 'when not elevated' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy sudo -MockWith $sudoMock
            InModuleScope easypeasy { Mock Get-SudoModeValue { [SudoMode]::Inline } }
        }

        It 'creates the shortcut in the Programs root elevated for -AllUsers' {
            $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'ElevatedRoot' -AllUsers

            "$folder\ElevatedRoot.lnk" | Should -Exist
            $shortcut.Location  | Should -Be "$folder\ElevatedRoot.lnk"
            $shortcut.Target    | Should -Match 'pwsh'
            $shortcut.Arguments | Should -Be '-Command "Get-Date"'
            Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly
        }

        It 'creates the shortcut in the given -Folder elevated for -AllUsers' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersFolder' -Folder 'AllUsersDir' -AllUsers | Out-Null

            "$folder\AllUsersDir\AllUsersFolder.lnk" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly
        }

        It 'carries every field into the shortcut it creates for -AllUsers' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersFields' -AllUsers `
                -KeepOpen `
                -RunLocation 'C:\temp' `
                -Description 'Show the date' `
                -Icon 'C:\Windows\explorer.exe,3' `
                -Hotkey 'Ctrl+Alt+D' `
                -WindowStyle Maximized `
                -Elevated | Out-Null

            $result = Get-Shortcut "$folder\AllUsersFields.lnk"
            $result.Arguments       | Should -Be '-NoExit -Command "Get-Date"'
            $result.RunLocation     | Should -Be 'C:\temp'
            $result.Description     | Should -Be 'Show the date'
            $result.Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,3'
            $result.Hotkey          | Should -Be 'Alt+Ctrl+D'
            $result.WindowStyle     | Should -Be 'Maximized'
            $result.Elevated        | Should -BeTrue
        }

        It 'leaves the run location empty for -AllUsers when it is omitted' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersNoRunLocation' -AllUsers | Out-Null

            (Get-Shortcut "$folder\AllUsersNoRunLocation.lnk").RunLocation | Should -BeNullOrEmpty
        }

        It 'fails for -AllUsers when the shortcut already exists without -Force' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersDup' -AllUsers | Out-Null

            { New-PowershellStartMenuShortcut -Command 'Get-ChildItem' -Name 'AllUsersDup' -AllUsers } |
                Should -Throw '*already exists*'

            (Get-Shortcut "$folder\AllUsersDup.lnk").Arguments | Should -Match 'Get-Date'
        }

        It 'overwrites an existing shortcut for -AllUsers with -Force' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersOver' -AllUsers | Out-Null

            New-PowershellStartMenuShortcut -Command 'Get-ChildItem' -Name 'AllUsersOver' -AllUsers -Force | Out-Null

            (Get-Shortcut "$folder\AllUsersOver.lnk").Arguments | Should -Match 'Get-ChildItem'
        }

        It 'does not elevate for the current user' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'UserShortcut' | Out-Null

            "$folder\UserShortcut.lnk" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'creates nothing and does not elevate under -WhatIf' {
            New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'WhatIfAllUsers' -AllUsers -WhatIf | Out-Null

            "$folder\WhatIfAllUsers.lnk" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'fails for -AllUsers before anything is created when sudo is not available' {
            InModuleScope easypeasy { Mock Get-SudoModeValue { [SudoMode]::Disabled } }

            { New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'NoSudo' -AllUsers } | Should -Throw '*sudo*'

            "$folder\NoSudo.lnk" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }
    }

    It 'fails when the shortcut already exists without -Force' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Dup' | Out-Null

        { New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Dup' } |
            Should -Throw '*already exists*'
    }

    It 'overwrites an existing shortcut with -Force' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Over' | Out-Null

        (New-PowershellStartMenuShortcut -Command 'Get-ChildItem' -Name 'Over' -Force).Arguments |
            Should -Match 'Get-ChildItem'
    }

    It 'sets every field passed' {
        $shortcut = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'EveryField' `
            -RunLocation 'C:\temp' `
            -Description 'Show the date' `
            -Icon 'C:\Windows\explorer.exe,3' `
            -Hotkey 'Ctrl+Alt+D'

        $result = Get-Shortcut $shortcut.Location
        $result.RunLocation     | Should -Be 'C:\temp'
        $result.Description     | Should -Be 'Show the date'
        $result.Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,3'
        $result.Hotkey          | Should -Be 'Alt+Ctrl+D'
    }

    It 'takes the icon as an icon file and an index' {
        $icon = (New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconWithIndex' `
                -Icon 'C:\Windows\explorer.exe,3').Icon

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 3
    }

    It 'takes the icon as an icon file on its own, at index 0' {
        $icon = (New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconFileOnly' `
                -Icon 'C:\Windows\explorer.exe').Icon

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 0
    }
}
