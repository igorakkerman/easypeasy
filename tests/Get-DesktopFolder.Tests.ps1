BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-DesktopFolder' {

    It 'returns an existing directory' {
        $location = Get-DesktopFolder
        $location | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $location -PathType Container | Should -BeTrue
    }
}
