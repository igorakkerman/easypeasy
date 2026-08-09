BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-ProgramFilesFolder' {

    It 'returns an existing directory' {
        $location = Get-ProgramFilesFolder
        $location | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $location -PathType Container | Should -BeTrue
    }
}
