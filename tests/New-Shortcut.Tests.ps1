BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'New-Shortcut' {

    BeforeEach {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
    }

    AfterEach { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'exports the command' {
        Get-Command New-Shortcut -Module easypeasy | Should -Not -BeNullOrEmpty
    }

    It 'requires only the shortcut location and the target' {
        $parameters = (Get-Command New-Shortcut).Parameters

        $parameters.Location.Attributes.Mandatory | Should -Contain $true
        $parameters.Target.Attributes.Mandatory | Should -Contain $true
        foreach ($name in 'Arguments', 'RunLocation', 'Description', 'Icon', 'Hotkey', 'WindowStyle', 'Elevated', 'Force') {
            $parameters[$name].Attributes.Mandatory | Should -Not -Contain $true
        }
    }

    It 'creates a shortcut at the given location' {
        New-Shortcut -Location $lnk -Target 'C:\Windows\notepad.exe' | Out-Null

        Test-Path -LiteralPath $lnk | Should -BeTrue
        (Get-Shortcut $lnk).Target | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'returns the created shortcut' {
        $result = New-Shortcut $lnk 'C:\Windows\notepad.exe'

        $result.GetType().Name | Should -Be 'Shortcut'
        $result.Location | Should -Be $lnk
        $result.Target   | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'takes shortcut location and target positionally' {
        New-Shortcut $lnk 'C:\Windows\notepad.exe' | Out-Null

        (Get-Shortcut $lnk).Target | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'defaults the run location to the folder of the target' {
        New-Shortcut $lnk 'C:\Windows\notepad.exe' | Out-Null

        (Get-Shortcut $lnk).RunLocation | Should -Be 'C:\Windows'
    }

    It 'defaults every optional field' {
        New-Shortcut $lnk 'C:\Windows\notepad.exe' | Out-Null

        $result = Get-Shortcut $lnk
        $result.Arguments   | Should -BeNullOrEmpty
        $result.Description | Should -BeNullOrEmpty
        $result.Icon        | Should -BeNullOrEmpty
        $result.Hotkey      | Should -BeNullOrEmpty
        $result.WindowStyle | Should -Be 'Normal'
        $result.Elevated    | Should -BeFalse
    }

    It 'sets every field passed' {
        New-Shortcut -Location $lnk -Target 'C:\Windows\notepad.exe' `
            -Arguments '/A C:\temp\file.txt' `
            -RunLocation 'C:\temp' `
            -Description 'Edit file' `
            -Icon (New-ShortcutIcon 'C:\Windows\notepad.exe,0') `
            -Hotkey 'Ctrl+Alt+N' `
            -WindowStyle Maximized `
            -Elevated | Out-Null

        $result = Get-Shortcut $lnk
        $result.Target      | Should -Be 'C:\Windows\notepad.exe'
        $result.Arguments   | Should -Be '/A C:\temp\file.txt'
        $result.RunLocation | Should -Be 'C:\temp'
        $result.Description | Should -Be 'Edit file'
        $result.Icon.ToString()  | Should -Be 'C:\Windows\notepad.exe,0'
        $result.Hotkey      | Should -Be 'Alt+Ctrl+N'
        $result.WindowStyle | Should -Be 'Maximized'
        $result.Elevated    | Should -BeTrue
    }

    It 'takes the icon as a ShortcutIcon record' {
        $icon = New-ShortcutIcon -Location 'C:\Windows\explorer.exe' -Index 3

        $result = (New-Shortcut $lnk 'C:\Windows\notepad.exe' -Icon $icon).Icon
        $result.Location | Should -Be 'C:\Windows\explorer.exe'
        $result.Index    | Should -Be 3
    }

    It 'takes the icon read off another shortcut' {
        $source = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        try {
            $icon = (New-Shortcut $source 'C:\Windows\notepad.exe' -Icon (New-ShortcutIcon 'C:\Windows\explorer.exe,4')).Icon

            (New-Shortcut $lnk 'C:\Windows\notepad.exe' -Icon $icon).Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,4'
        }
        finally {
            Remove-Item $source -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects an icon that is not a ShortcutIcon record' {
        { New-Shortcut $lnk 'C:\Windows\notepad.exe' -Icon 'C:\Windows\explorer.exe,1' } |
            Should -Throw '*ShortcutIcon*'

        Test-Path -LiteralPath $lnk | Should -BeFalse
    }

    It 'clears the run location passed as $null, where omitting it defaults to the folder of the target' {
        New-Shortcut $lnk 'C:\Windows\notepad.exe' -RunLocation $null | Out-Null

        (Get-Shortcut $lnk).RunLocation | Should -BeNullOrEmpty
    }

    It 'accepts -Administrator as alias of -Elevated' {
        New-Shortcut -Location $lnk -Target 'C:\Windows\notepad.exe' -Administrator | Out-Null

        (Get-Shortcut $lnk).Elevated | Should -BeTrue
    }

    It 'reports an error when the shortcut already exists' {
        New-Shortcut $lnk 'C:\Windows\notepad.exe' | Out-Null

        $errorRecord = { New-Shortcut $lnk 'C:\Windows\regedit.exe' } | Should -Throw '*already exists*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'ResourceExists'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ShortcutAlreadyExists,*'
        $errorRecord.TargetObject | Should -Be $lnk
        (Get-Shortcut $lnk).Target | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'overwrites an existing shortcut with -Force' {
        New-Shortcut $lnk 'C:\Windows\notepad.exe' `
            -Arguments '/A C:\temp\file.txt' `
            -RunLocation 'C:\temp' `
            -Description 'Old description' `
            -Icon (New-ShortcutIcon 'C:\Windows\explorer.exe,3') `
            -Hotkey 'Ctrl+Alt+N' `
            -WindowStyle Maximized `
            -Elevated | Out-Null

        New-Shortcut $lnk 'C:\Windows\regedit.exe' -Force | Out-Null

        $result = Get-Shortcut $lnk
        $result.Target      | Should -Be 'C:\Windows\regedit.exe'
        $result.Arguments   | Should -BeNullOrEmpty
        $result.RunLocation | Should -Be 'C:\Windows'
        $result.Description | Should -BeNullOrEmpty
        $result.Icon        | Should -BeNullOrEmpty
        $result.Hotkey      | Should -BeNullOrEmpty
        $result.WindowStyle | Should -Be 'Normal'
        $result.Elevated    | Should -BeFalse
    }

    It 'reports a terminating error when the shortcut folder does not exist' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid)\MyApp.lnk"

        $errorRecord = { New-Shortcut $missing 'C:\Windows\notepad.exe' } |
            Should -Throw '*folder not found*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ShortcutFolderNotFound,*'
        $errorRecord.TargetObject | Should -Be (Split-Path -Parent $missing)
        Test-Path -LiteralPath $missing | Should -BeFalse
    }

    It 'reports the missing shortcut folder under -WhatIf too' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid)\MyApp.lnk"

        $errorRecord = { New-Shortcut $missing 'C:\Windows\notepad.exe' -WhatIf } |
            Should -Throw '*folder not found*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'ObjectNotFound'
    }

    It 'creates the missing shortcut folder with -CreateFolder' {
        $folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid)"
        try {
            $result = New-Shortcut "$folder\MyApp.lnk" 'C:\Windows\notepad.exe' -CreateFolder

            $folder | Should -Exist
            $result.Target | Should -Be 'C:\Windows\notepad.exe'
        }
        finally {
            Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports no missing shortcut folder under -WhatIf with -CreateFolder' {
        $folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid)"

        New-Shortcut "$folder\MyApp.lnk" 'C:\Windows\notepad.exe' -CreateFolder -WhatIf `
            -ErrorVariable shortcutError -ErrorAction SilentlyContinue

        $shortcutError | Should -BeNullOrEmpty
        $folder | Should -Not -Exist
    }

    It 'creates nothing and returns nothing under -WhatIf' {
        $result = New-Shortcut $lnk 'C:\Windows\notepad.exe' -WhatIf

        $result | Should -BeNullOrEmpty
        Test-Path -LiteralPath $lnk | Should -BeFalse
    }
}
