BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-MyDocumentsFolder' {

    It 'returns an existing directory' {
        $location = Get-MyDocumentsFolder
        $location | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $location -PathType Container | Should -BeTrue
    }
}
