BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-ProgramFilesFolder' {

    It 'returns an existing directory' {
        $location = Get-ProgramFilesFolder
        $location | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $location -PathType Container | Should -BeTrue
    }

    It 'returns the ProgramFiles special folder' {
        Get-ProgramFilesFolder |
            Should -Be ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles))
    }
}
