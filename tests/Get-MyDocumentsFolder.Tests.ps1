BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-MyDocumentsFolder' {

    It 'returns an existing directory' {
        $path = Get-MyDocumentsFolder
        $path | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $path -PathType Container | Should -BeTrue
    }
}
