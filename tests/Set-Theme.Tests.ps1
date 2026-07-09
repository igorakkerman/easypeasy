BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Set-Theme' {

    BeforeEach {
        Mock -ModuleName easypeasy Set-ItemProperty { }
        Mock -ModuleName easypeasy Send-ThemeChangeBroadcast { }
    }

    It 'writes 0 for the dark theme' {
        Set-Theme -Theme dark

        Should -Invoke -ModuleName easypeasy Set-ItemProperty -ParameterFilter {
            $Name -eq 'AppsUseLightTheme' -and $Value -eq 0
        }
    }

    It 'writes 1 for the light theme' {
        Set-Theme -Theme light

        Should -Invoke -ModuleName easypeasy Set-ItemProperty -ParameterFilter {
            $Name -eq 'AppsUseLightTheme' -and $Value -eq 1
        }
    }

    It 'broadcasts the change' {
        Set-Theme -Theme dark
        Should -Invoke -ModuleName easypeasy Send-ThemeChangeBroadcast -Times 1
    }

    It 'rejects an invalid theme' {
        { Set-Theme -Theme purple } | Should -Throw
    }

    It 'writes nothing under -WhatIf' {
        Set-Theme -Theme dark -WhatIf
        Should -Invoke -ModuleName easypeasy Set-ItemProperty -Times 0 -Exactly
    }
}
