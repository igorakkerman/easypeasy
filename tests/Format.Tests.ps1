BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'easypeasy.format.ps1xml' {

    Context 'registered views' {

        It 'registers a <control> for <type>' -ForEach @(
            @{ type = 'EnvironmentVariable'; control = 'TableControl' }
            @{ type = 'Shortcut'; control = 'ListControl' }
            @{ type = 'SystemPathLocation'; control = 'TableControl' }
        ) {
            $view = Get-FormatData -TypeName $type -PowerShellVersion $PSVersionTable.PSVersion

            $view | Should -Not -BeNullOrEmpty
            $view.FormatViewDefinition[0].Control.GetType().Name | Should -Be $control
        }
    }

    Context 'SystemPathLocation' {

        It 'renders scope and location as table columns' {
            $rendered = Get-SystemPath -Machine | Select-Object -First 1 | Out-String -Width 200

            $rendered | Should -Match 'Scope'
            $rendered | Should -Match 'Location'
        }

        It 'renders the stored form underneath the expanded location where they differ' {
            $entry = Get-SystemPath -Machine | Select-Object -First 1
            $entry | Should -Not -BeNullOrEmpty

            $entry.Location = 'C:\Windows\system32'
            $entry.StoredValue = '%SystemRoot%\system32'

            $rendered = $entry | Out-String -Width 200

            $rendered | Should -Match ([regex]::Escape('C:\Windows\system32'))
            $rendered | Should -Match ([regex]::Escape('%SystemRoot%\system32'))
        }

        It 'renders the location once where the stored form matches it' {
            $entry = Get-SystemPath -Machine | Select-Object -First 1
            $entry.Location = 'C:\Windows\system32'
            $entry.StoredValue = 'C:\Windows\system32'

            $rendered = $entry | Out-String -Width 200

            @([regex]::Matches($rendered, [regex]::Escape('C:\Windows\system32'))).Count | Should -Be 1
        }
    }

    Context 'EnvironmentVariable' {

        It 'renders scope, name and value as table columns' {
            $rendered = Get-Environment -User | Select-Object -First 1 | Out-String -Width 200

            $rendered | Should -Match 'Scope'
            $rendered | Should -Match 'Name'
            $rendered | Should -Match 'Value'
        }
    }

    Context 'Shortcut' {

        BeforeAll {
            $script:lnk = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
            New-Shortcut $lnk 'C:\Windows\notepad.exe' -Icon (New-ShortcutIcon 'C:\Windows\explorer.exe,3') | Out-Null
        }

        AfterAll { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }

        It 'renders <field> as a list label' -ForEach @(
            @{ field = 'Location' }
            @{ field = 'Target' }
            @{ field = 'Arguments' }
            @{ field = 'RunLocation' }
            @{ field = 'Description' }
            @{ field = 'Icon' }
            @{ field = 'Hotkey' }
            @{ field = 'WindowStyle' }
            @{ field = 'Elevated' }
        ) {
            $rendered = Get-Shortcut $lnk | Out-String -Width 200

            $rendered | Should -Match "$field\s*:"
        }

        It 'renders the icon as its combined stored source' {
            $rendered = Get-Shortcut $lnk | Out-String -Width 200

            $rendered | Should -Match ([regex]::Escape('C:\Windows\explorer.exe,3'))
        }

        It 'renders no icon for a shortcut carrying none' {
            $withoutIcon = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-$(New-Guid).lnk"
            try {
                New-Shortcut $withoutIcon 'C:\Windows\notepad.exe' | Out-Null

                $rendered = Get-Shortcut $withoutIcon | Out-String -Width 200

                $rendered | Should -Match 'Icon\s*:\s*\r?\n'
            }
            finally {
                Remove-Item $withoutIcon -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
