BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-Theme' {

    It 'reports "light" when SystemUsesLightTheme is 1' {
        Mock -ModuleName easypeasy Get-ItemPropertyValue { 1 }
        Get-Theme | Should -Be 'light'
    }

    It 'reports "dark" when SystemUsesLightTheme is 0' {
        Mock -ModuleName easypeasy Get-ItemPropertyValue { 0 }
        Get-Theme | Should -Be 'dark'
    }

    It 'throws on an unexpected registry value' {
        Mock -ModuleName easypeasy Get-ItemPropertyValue { 2 }
        { Get-Theme } | Should -Throw '*unexpected value*'
    }
}
