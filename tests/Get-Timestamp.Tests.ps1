BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-Timestamp' {

    It 'formats the current instant as yyyy-MM-dd_HH.mm.ss' {
        # Format a fixed instant so the assertion does not depend on the clock.
        Mock -ModuleName easypeasy Get-Date { ([datetime]::new(2024, 1, 2, 3, 4, 5)).ToString($Format) }

        Get-Timestamp | Should -Be '2024-01-02_03.04.05'
    }
}
