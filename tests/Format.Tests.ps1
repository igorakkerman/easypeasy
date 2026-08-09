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

        BeforeAll {
            # the escapes $PSStyle emits are stripped at PlainText, so the glyphs and the layout can be
            # asserted without the host deciding whether colour is on
            $script:originalRendering = $PSStyle.OutputRendering
            $PSStyle.OutputRendering = 'PlainText'

            # a folder that exists and one that does not, both outside anything the module writes
            $script:present = $env:SystemRoot
            $script:absent = Join-Path $env:SystemRoot 'EasypeasyNoSuchFolder'

            function script:New-Rendered {
                param ([string] $StoredValue, [AllowNull()] $Location)

                $entry = InModuleScope easypeasy -Parameters @{ s = $StoredValue; l = $Location } {
                    [SystemPathLocation]::new('Machine', $s, $l)
                }
                return $entry | Out-String -Width 200
            }
        }

        AfterAll { $PSStyle.OutputRendering = $script:originalRendering }

        It 'renders scope and location as table columns' {
            $rendered = Get-SystemPath -Machine | Select-Object -First 1 | Out-String -Width 200

            $rendered | Should -Match 'Scope'
            $rendered | Should -Match 'Location'
        }

        It 'renders the stored value alone where the location matches it' {
            $rendered = New-Rendered -StoredValue $present -Location $present

            @([regex]::Matches($rendered, [regex]::Escape($present))).Count | Should -Be 1
            $rendered | Should -Not -Match '↳'
        }

        It 'renders the resolved location underneath a %...% reference' {
            $rendered = New-Rendered -StoredValue '%SystemRoot%\system32' -Location $present

            $rendered | Should -Match "$([regex]::Escape('%SystemRoot%\system32'))\r?\n\s*↳ $([regex]::Escape($present))"
        }

        It 'renders the stored value alone where <case> hid no folder' -ForEach @(
            @{ case = 'repeated backslashes'; stored = 'C:\Tools\\bin' }
            @{ case = 'a trailing backslash'; stored = 'C:\Tools\bin\' }
            @{ case = 'a .. segment'; stored = 'C:\Tools\other\..\bin' }
        ) {
            $rendered = New-Rendered -StoredValue $stored -Location 'C:\Tools\bin'

            $rendered | Should -Match ([regex]::Escape($stored))
            $rendered | Should -Not -Match '↳'
        }

        It 'renders no warning symbol for a location naming no existing folder' {
            $rendered = New-Rendered -StoredValue '%SystemRoot%\EasypeasyNoSuchFolder' -Location $absent

            $rendered | Should -Match "↳ $([regex]::Escape($absent))"
            $rendered | Should -Not -Match '⚠'
        }

        It 'accents the resolved location where its folder does not exist' {
            $PSStyle.OutputRendering = 'Ansi'
            try { $rendered = New-Rendered -StoredValue '%SystemRoot%\EasypeasyNoSuchFolder' -Location $absent }
            finally { $PSStyle.OutputRendering = 'PlainText' }

            $rendered | Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))↳ $([regex]::Escape($absent))"
        }

        It 'accents the stored value where the location cannot be resolved' {
            $PSStyle.OutputRendering = 'Ansi'
            try { $rendered = New-Rendered -StoredValue 'C:\Invalid' -Location $null }
            finally { $PSStyle.OutputRendering = 'PlainText' }

            $rendered | Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))C:\\Invalid"
            $rendered | Should -Not -Match '↳'
        }

        It 'accents an unresolved %...% reference and gives it no resolved row' {
            $PSStyle.OutputRendering = 'Ansi'
            try { $rendered = New-Rendered -StoredValue '%EASYPEASY_UNSET_XYZ%\bin' -Location $null }
            finally { $PSStyle.OutputRendering = 'PlainText' }

            $rendered |
                Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))$([regex]::Escape('%EASYPEASY_UNSET_XYZ%\bin'))"
            $rendered | Should -Not -Match '↳'
        }

        It 'accents the single row where the stored value is itself the missing folder' {
            $PSStyle.OutputRendering = 'Ansi'
            try { $rendered = New-Rendered -StoredValue $absent -Location $absent }
            finally { $PSStyle.OutputRendering = 'PlainText' }

            $rendered | Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))$([regex]::Escape($absent))"
            $rendered | Should -Not -Match '↳'
        }

        It 'leaves a location naming an existing folder unaccented' {
            $PSStyle.OutputRendering = 'Ansi'
            try { $rendered = New-Rendered -StoredValue $present -Location $present }
            finally { $PSStyle.OutputRendering = 'PlainText' }

            $rendered | Should -Not -Match ([regex]::Escape($PSStyle.Foreground.Red))
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
            New-Shortcut $lnk 'C:\Windows\notepad.exe' -Icon 'C:\Windows\explorer.exe,3' | Out-Null
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
