BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Set-Shortcut' {

    BeforeEach {
        $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        New-Shortcut -Location $lnk -Target 'C:\Windows\notepad.exe' `
            -Arguments '/A C:\temp\file.txt' `
            -RunLocation 'C:\temp' `
            -Description 'Edit file' `
            -Icon (New-ShortcutIcon -Location 'C:\Windows\explorer.exe' -Index 1) `
            -Hotkey 'Ctrl+Alt+N' `
            -WindowStyle Maximized | Out-Null
    }

    AfterEach { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

    It 'exports the command' {
        Get-Command Set-Shortcut -Module easypeasy | Should -Not -BeNullOrEmpty
    }

    It 'requires only the shortcut location' {
        $parameters = (Get-Command Set-Shortcut).Parameters

        $parameters.Location.Attributes.Mandatory | Should -Contain $true
        foreach ($name in 'Target', 'Arguments', 'RunLocation', 'Description', 'Icon', 'Hotkey', 'WindowStyle', 'Elevated', 'PassThru') {
            $parameters[$name].Attributes.Mandatory | Should -Not -Contain $true
        }
    }

    It 'sets a single field, leaving the others untouched' {
        Set-Shortcut -Location $lnk -Target 'C:\Windows\regedit.exe'

        $result = Get-Shortcut $lnk
        $result.Target      | Should -Be 'C:\Windows\regedit.exe'
        $result.Arguments   | Should -Be '/A C:\temp\file.txt'
        $result.RunLocation | Should -Be 'C:\temp'
        $result.Description | Should -Be 'Edit file'
        $result.Icon.ToString()  | Should -Be 'C:\Windows\explorer.exe,1'
        $result.Hotkey      | Should -Be 'Alt+Ctrl+N'
        $result.WindowStyle | Should -Be 'Maximized'
    }

    It 'takes the shortcut location positionally' {
        Set-Shortcut $lnk -Description 'Another description'

        (Get-Shortcut $lnk).Description | Should -Be 'Another description'
    }

    It 'sets any combination of fields' {
        Set-Shortcut $lnk -Arguments '/B' -Hotkey 'Ctrl+Alt+E' -WindowStyle Minimized

        $result = Get-Shortcut $lnk
        $result.Arguments   | Should -Be '/B'
        $result.Hotkey      | Should -Be 'Alt+Ctrl+E'
        $result.WindowStyle | Should -Be 'Minimized'
        $result.Target      | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'sets the icon' {
        Set-Shortcut $lnk -Icon (New-ShortcutIcon 'C:\Windows\notepad.exe,2')

        (Get-Shortcut $lnk).Icon.ToString() | Should -Be 'C:\Windows\notepad.exe,2'
    }

    It 'sets the icon read off another shortcut' {
        $icon = (Get-Shortcut $lnk).Icon

        Set-Shortcut $lnk -Icon (New-ShortcutIcon 'C:\Windows\notepad.exe,2')
        Set-Shortcut $lnk -Icon $icon

        (Get-Shortcut $lnk).Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,1'
    }

    It 'rejects an icon that is not a ShortcutIcon record' {
        { Set-Shortcut $lnk -Icon 'C:\Windows\notepad.exe,2' } | Should -Throw '*ShortcutIcon*'

        (Get-Shortcut $lnk).Icon.ToString() | Should -Be 'C:\Windows\explorer.exe,1'
    }

    It 'clears a field passed as an empty string' {
        Set-Shortcut $lnk -Arguments '' -RunLocation '' -Description '' -Hotkey ''

        $result = Get-Shortcut $lnk
        $result.Arguments   | Should -BeNullOrEmpty
        $result.RunLocation | Should -BeNullOrEmpty
        $result.Description | Should -BeNullOrEmpty
        $result.Hotkey      | Should -BeNullOrEmpty
    }

    It 'clears a field passed as $null' {
        Set-Shortcut $lnk -Arguments $null -RunLocation $null -Description $null -Hotkey $null -Icon $null

        $result = Get-Shortcut $lnk
        $result.Arguments   | Should -BeNullOrEmpty
        $result.RunLocation | Should -BeNullOrEmpty
        $result.Description | Should -BeNullOrEmpty
        $result.Hotkey      | Should -BeNullOrEmpty
        $result.Icon        | Should -BeNullOrEmpty
    }

    It 'leaves fields it is not given while clearing the ones it is' {
        Set-Shortcut $lnk -Arguments $null

        $result = Get-Shortcut $lnk
        $result.Arguments   | Should -BeNullOrEmpty
        $result.Description | Should -Be 'Edit file'
        $result.Icon.ToString()  | Should -Be 'C:\Windows\explorer.exe,1'
    }

    It 'sets the run-as-administrator flag' {
        Set-Shortcut $lnk -Elevated

        (Get-Shortcut $lnk).Elevated | Should -BeTrue
    }

    It 'clears the run-as-administrator flag' {
        Set-Shortcut $lnk -Elevated
        Set-Shortcut $lnk -Elevated:$false

        (Get-Shortcut $lnk).Elevated | Should -BeFalse
    }

    It 'keeps the run-as-administrator flag when setting other fields' {
        Set-Shortcut $lnk -Elevated
        Set-Shortcut $lnk -Target 'C:\Windows\regedit.exe'

        (Get-Shortcut $lnk).Elevated | Should -BeTrue
    }

    It 'accepts -Administrator as alias of -Elevated' {
        Set-Shortcut -Location $lnk -Administrator

        (Get-Shortcut $lnk).Elevated | Should -BeTrue
    }

    It 'requires at least one field' {
        $errorRecord = { Set-Shortcut $lnk } | Should -Throw '*at least one shortcut field*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'InvalidArgument'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'MissingShortcutField,*'
        $errorRecord.TargetObject | Should -Be $lnk
    }

    It 'returns nothing without -PassThru' {
        Set-Shortcut $lnk -Description 'Another description' | Should -BeNullOrEmpty
    }

    It 'returns the shortcut with -PassThru' {
        $result = Set-Shortcut $lnk -Description 'Another description' -PassThru

        $result.GetType().Name | Should -Be 'Shortcut'
        $result.Location    | Should -Be $lnk
        $result.Description | Should -Be 'Another description'
    }

    It 'reports an error when the shortcut does not exist' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"

        Set-Shortcut $missing -Target 'C:\Windows\notepad.exe' -ErrorVariable shortcutError -ErrorAction SilentlyContinue

        $shortcutError.CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $shortcutError.FullyQualifiedErrorId | Should -BeLike 'ShortcutNotFound,*'
        $shortcutError.TargetObject | Should -Be $missing
        Test-Path -LiteralPath $missing | Should -BeFalse
    }

    It 'leaves the shortcut untouched under -WhatIf' {
        Set-Shortcut $lnk -Target 'C:\Windows\regedit.exe' -WindowStyle Normal -WhatIf

        $result = Get-Shortcut $lnk
        $result.Target      | Should -Be 'C:\Windows\notepad.exe'
        $result.WindowStyle | Should -Be 'Maximized'
    }
}
