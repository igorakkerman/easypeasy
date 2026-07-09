BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-DesktopFolder' {

    It 'returns an existing directory' {
        $path = Get-DesktopFolder
        $path | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $path -PathType Container | Should -BeTrue
    }
}
