BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'New-ShortcutIcon' {

    It 'exports the command' {
        Get-Command New-ShortcutIcon -Module easypeasy | Should -Not -BeNullOrEmpty
    }

    It 'returns a ShortcutIcon record' {
        (New-ShortcutIcon 'C:\Windows\explorer.exe,3').GetType().Name | Should -Be 'ShortcutIcon'
    }

    It 'takes the combined source positionally' {
        $icon = New-ShortcutIcon 'C:\Windows\explorer.exe,3'

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 3
    }

    It 'takes the icon file and index separately' {
        $icon = New-ShortcutIcon -Location 'C:\Windows\explorer.exe' -Index 3

        $icon.Location | Should -Be 'C:\Windows\explorer.exe'
        $icon.Index    | Should -Be 3
    }

    It 'defaults the index to 0' {
        (New-ShortcutIcon -Location 'C:\Windows\explorer.exe').Index | Should -Be 0
    }

    It 'combines the icon file and index back into the stored source' {
        $icon = New-ShortcutIcon -Location 'C:\Windows\explorer.exe' -Index 3

        $icon.ToString() | Should -Be 'C:\Windows\explorer.exe,3'
        "$icon"          | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'carries no Value property' {
        (New-ShortcutIcon -Location 'C:\Windows\explorer.exe').PSObject.Properties.Name | Should -Be @('Location', 'Index')
    }

    It 'splits an icon file containing a comma at the last comma' {
        $icon = New-ShortcutIcon 'C:\My,Apps\App.exe,2'

        $icon.Location | Should -Be 'C:\My,Apps\App.exe'
        $icon.Index    | Should -Be 2
    }

    It 'keeps an icon file containing a comma whole under -Location' {
        (New-ShortcutIcon -Location 'C:\My,Apps\App.exe').Location | Should -Be 'C:\My,Apps\App.exe'
    }

    It 'rejects an icon file on its own as -Value' {
        $errorRecord = { New-ShortcutIcon 'C:\Windows\explorer.exe' } | Should -Throw '*as ?file,index?*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'InvalidArgument'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'InvalidShortcutIconValue,*'
    }

    It 'rejects a non-numeric index' {
        { New-ShortcutIcon 'C:\Windows\explorer.exe,x' } | Should -Throw '*as ?file,index?*'
    }

    It 'rejects a source naming no icon file' {
        $errorRecord = { New-ShortcutIcon ',0' } | Should -Throw '*names no icon file*' -PassThru

        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'BlankShortcutIconLocation,*'
    }

    It 'requires the icon file in the Location parameter set' {
        (Get-Command New-ShortcutIcon).Parameters.Location.Attributes.Mandatory | Should -Contain $true
        (Get-Command New-ShortcutIcon).Parameters.Index.Attributes.Mandatory | Should -Not -Contain $true
    }

    It 'round-trips an icon read by Get-Shortcut' {
        $lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
        try {
            New-Shortcut $lnk 'C:\Windows\notepad.exe' -Icon (New-ShortcutIcon 'C:\Windows\explorer.exe,4') | Out-Null

            $icon = (Get-Shortcut $lnk).Icon
            (New-ShortcutIcon $icon.ToString()).ToString() | Should -Be 'C:\Windows\explorer.exe,4'
        }
        finally {
            Remove-Item $lnk -Force -ErrorAction SilentlyContinue
        }
    }
}
