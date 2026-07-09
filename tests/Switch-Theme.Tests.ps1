BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Switch-Theme' {

    BeforeEach { Mock -ModuleName easypeasy Set-Theme { } }

    It 'switches dark to light' {
        Mock -ModuleName easypeasy Get-Theme { 'dark' }

        Switch-Theme

        Should -Invoke -ModuleName easypeasy Set-Theme -ParameterFilter { $Theme -eq 'light' }
    }

    It 'switches light to dark' {
        Mock -ModuleName easypeasy Get-Theme { 'light' }

        Switch-Theme

        Should -Invoke -ModuleName easypeasy Set-Theme -ParameterFilter { $Theme -eq 'dark' }
    }

    It 'sets the theme explicitly when one is given' {
        Mock -ModuleName easypeasy Get-Theme { 'light' }

        Switch-Theme -Theme light

        Should -Invoke -ModuleName easypeasy Set-Theme -ParameterFilter { $Theme -eq 'light' }
        Should -Invoke -ModuleName easypeasy Get-Theme -Times 0 -Exactly
    }
}
