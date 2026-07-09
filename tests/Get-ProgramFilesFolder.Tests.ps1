BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-ProgramFilesFolder' {

    It 'returns an existing directory' {
        $path = Get-ProgramFilesFolder
        $path | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $path -PathType Container | Should -BeTrue
    }
}
