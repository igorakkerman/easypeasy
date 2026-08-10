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
            # asserted without the host deciding whether color is on
            $script:originalRendering = $PSStyle.OutputRendering
            $PSStyle.OutputRendering = 'PlainText'

            # the marking settings are read from the process environment, so the host's own values would
            # otherwise decide how these tests render
            $script:originalUseColors = $env:EASYPEASY_USE_COLORS
            $script:originalUseWarningSymbol = $env:EASYPEASY_USE_WARNING_SYMBOL
            $env:EASYPEASY_USE_COLORS = $null
            $env:EASYPEASY_USE_WARNING_SYMBOL = $null

            # a folder that exists and one that does not, both outside anything the module writes
            $script:present = $env:SystemRoot
            $script:absent = Join-Path $env:SystemRoot 'EasypeasyNoSuchFolder'

            # the symbol the format file trails a missing folder with, named once so the two stay in step
            $script:warningSymbol = "`u{26A0}"

            function script:New-Rendered {
                [CmdletBinding()]
                param ([string] $StoredValue, [AllowNull()] $Location)

                $entry = InModuleScope easypeasy -Parameters @{ s = $StoredValue; l = $Location } {
                    [SystemPathLocation]::new('Machine', $s, $l)
                }
                # Format-Table spelled out rather than left to Out-String: a warning the view raises reaches
                # the warning stream through it, and goes straight to the host without it, out of a
                # redirection's reach. Renders the same either way.
                return $entry | Format-Table | Out-String -Width 200
            }

            # color is only in the output at Ansi, the rendering the rest of these tests turn off
            function script:New-AnsiRendered {
                [CmdletBinding()]
                param ([string] $StoredValue, [AllowNull()] $Location)

                $PSStyle.OutputRendering = 'Ansi'
                try { return New-Rendered -StoredValue $StoredValue -Location $Location }
                finally { $PSStyle.OutputRendering = 'PlainText' }
            }
        }

        AfterAll {
            $PSStyle.OutputRendering = $script:originalRendering
            $env:EASYPEASY_USE_COLORS = $script:originalUseColors
            $env:EASYPEASY_USE_WARNING_SYMBOL = $script:originalUseWarningSymbol
        }

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

        It 'accents the resolved location where its folder does not exist' {
            $rendered = New-AnsiRendered -StoredValue '%SystemRoot%\EasypeasyNoSuchFolder' -Location $absent

            $rendered | Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))↳ $([regex]::Escape($absent))"
        }

        It 'accents the stored value where the location cannot be resolved' {
            $rendered = New-AnsiRendered -StoredValue 'C:\Invalid' -Location $null

            $rendered | Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))C:\\Invalid"
            $rendered | Should -Not -Match '↳'
        }

        It 'accents an unresolved %...% reference and gives it no resolved row' {
            $rendered = New-AnsiRendered -StoredValue '%EASYPEASY_UNSET_XYZ%\bin' -Location $null

            $rendered |
                Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))$([regex]::Escape('%EASYPEASY_UNSET_XYZ%\bin'))"
            $rendered | Should -Not -Match '↳'
        }

        It 'accents the single row where the stored value is itself the missing folder' {
            $rendered = New-AnsiRendered -StoredValue $absent -Location $absent

            $rendered | Should -Match "$([regex]::Escape($PSStyle.Foreground.Red))$([regex]::Escape($absent))"
            $rendered | Should -Not -Match '↳'
        }

        It 'leaves a location naming an existing folder unaccented' {
            $rendered = New-AnsiRendered -StoredValue $present -Location $present

            $rendered | Should -Not -Match ([regex]::Escape($PSStyle.Foreground.Red))
        }

        Context 'marking settings' {

            AfterEach {
                $env:EASYPEASY_USE_COLORS = $null
                $env:EASYPEASY_USE_WARNING_SYMBOL = $null
            }

            It 'trails a missing folder with no warning symbol by default' {
                $rendered = New-Rendered -StoredValue $absent -Location $absent

                $rendered | Should -Not -Match ([regex]::Escape($warningSymbol))
            }

            It 'trails a missing folder with the warning symbol where EASYPEASY_USE_WARNING_SYMBOL is <value>' -ForEach @(
                @{ value = 'true' }
                @{ value = 'TRUE' }
                @{ value = 'True' }
            ) {
                $env:EASYPEASY_USE_WARNING_SYMBOL = $value

                $rendered = New-Rendered -StoredValue $absent -Location $absent

                $rendered | Should -Match ([regex]::Escape("$absent $warningSymbol"))
            }

            It 'trails a missing folder with no warning symbol where EASYPEASY_USE_WARNING_SYMBOL is <value>' -ForEach @(
                @{ value = 'false' }
                @{ value = 'FALSE' }
                @{ value = 'False' }
            ) {
                $env:EASYPEASY_USE_WARNING_SYMBOL = $value

                $rendered = New-Rendered -StoredValue $absent -Location $absent

                $rendered | Should -Not -Match ([regex]::Escape($warningSymbol))
            }

            It 'trails the resolved row of a %...% reference with the warning symbol' {
                $env:EASYPEASY_USE_WARNING_SYMBOL = 'true'

                $rendered = New-Rendered -StoredValue '%SystemRoot%\EasypeasyNoSuchFolder' -Location $absent

                $rendered | Should -Match ([regex]::Escape("↳ $absent $warningSymbol"))
            }

            It 'trails an unresolved %...% reference with the warning symbol' {
                $env:EASYPEASY_USE_WARNING_SYMBOL = 'true'

                $rendered = New-Rendered -StoredValue '%EASYPEASY_UNSET_XYZ%\bin' -Location $null

                $rendered | Should -Match ([regex]::Escape("%EASYPEASY_UNSET_XYZ%\bin $warningSymbol"))
            }

            It 'leaves a row naming an existing folder as it renders without the symbol' {
                $unsigned = New-Rendered -StoredValue $present -Location $present

                $env:EASYPEASY_USE_WARNING_SYMBOL = 'true'
                $signed = New-Rendered -StoredValue $present -Location $present

                $signed | Should -Be $unsigned
            }

            It 'drops the color where EASYPEASY_USE_COLORS is <value>' -ForEach @(
                @{ value = 'false' }
                @{ value = 'FALSE' }
                @{ value = 'False' }
            ) {
                $env:EASYPEASY_USE_COLORS = $value

                $rendered = New-AnsiRendered -StoredValue $absent -Location $absent

                $rendered | Should -Match ([regex]::Escape($absent))
                $rendered | Should -Not -Match ([regex]::Escape($PSStyle.Foreground.Red))
            }

            It 'keeps the color where EASYPEASY_USE_COLORS is true' {
                $env:EASYPEASY_USE_COLORS = 'true'

                $rendered = New-AnsiRendered -StoredValue $absent -Location $absent

                $rendered | Should -Match ([regex]::Escape($PSStyle.Foreground.Red))
            }

            It 'treats <variable> set to an empty value as unset' -ForEach @(
                @{ variable = 'EASYPEASY_USE_COLORS' }
                @{ variable = 'EASYPEASY_USE_WARNING_SYMBOL' }
            ) {
                Set-Item "env:$variable" ''

                $rendered = New-AnsiRendered -StoredValue $absent -Location $absent

                $rendered | Should -Match ([regex]::Escape($PSStyle.Foreground.Red))
                $rendered | Should -Not -Match ([regex]::Escape($warningSymbol))
            }

            It 'leaves a missing folder unmarked where both settings are off' {
                $env:EASYPEASY_USE_COLORS = 'false'
                $env:EASYPEASY_USE_WARNING_SYMBOL = 'false'

                $rendered = New-AnsiRendered -StoredValue $absent -Location $absent

                $rendered | Should -Match ([regex]::Escape($absent))
                $rendered | Should -Not -Match ([regex]::Escape($PSStyle.Foreground.Red))
                $rendered | Should -Not -Match ([regex]::Escape($warningSymbol))
            }

            It 'wraps folder and symbol together in the color where both settings are on' {
                $env:EASYPEASY_USE_COLORS = 'true'
                $env:EASYPEASY_USE_WARNING_SYMBOL = 'true'

                $rendered = New-AnsiRendered -StoredValue $absent -Location $absent

                $rendered |
                    Should -Match ([regex]::Escape("$($PSStyle.Foreground.Red)$absent $warningSymbol$($PSStyle.Reset)"))
            }

            It 'warns where <variable> carries a value that is neither true nor false' -ForEach @(
                @{ variable = 'EASYPEASY_USE_COLORS' }
                @{ variable = 'EASYPEASY_USE_WARNING_SYMBOL' }
            ) {
                Set-Item "env:$variable" 'yes'

                # the format engine raises the warning from a nested pipeline, which -WarningVariable does
                # not reach; redirecting the stream into the output does
                $messages = New-Rendered -StoredValue $absent -Location $absent 3>&1

                "$messages" |
                    Should -BeLike "*Environment variable has invalid value. name: $variable, value: 'yes', expected: 'true' or 'false'*"
            }

            It 'falls back to the defaults where both values are neither true nor false' {
                $env:EASYPEASY_USE_COLORS = 'yes'
                $env:EASYPEASY_USE_WARNING_SYMBOL = 'yes'

                $rendered = New-AnsiRendered -StoredValue $absent -Location $absent 3>$null

                $rendered | Should -Match ([regex]::Escape($PSStyle.Foreground.Red))
                $rendered | Should -Not -Match ([regex]::Escape($warningSymbol))
            }
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
