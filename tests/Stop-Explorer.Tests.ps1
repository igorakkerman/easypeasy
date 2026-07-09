BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Stop-Explorer' {

    It 'stops the explorer process' {
        Mock -ModuleName easypeasy Stop-Process { }

        Stop-Explorer

        Should -Invoke -ModuleName easypeasy Stop-Process -Times 1 -Exactly `
            -ParameterFilter { $ProcessName -eq 'explorer' }
    }

    It 'does nothing under -WhatIf' {
        Mock -ModuleName easypeasy Stop-Process { }

        Stop-Explorer -WhatIf

        Should -Invoke -ModuleName easypeasy Stop-Process -Times 0 -Exactly
    }
}
